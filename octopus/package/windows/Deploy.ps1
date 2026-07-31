$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-RequiredOctopusParameter {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $value = $OctopusParameters[$Name]

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required Octopus variable '$Name' is empty or missing."
    }

    return $value
}

function ConvertTo-XmlText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    return [System.Security.SecurityElement]::Escape($Value)
}

$windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($windowsIdentity)

if (-not $windowsPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    throw "This deployment must run with local administrator permissions."
}

$displayName = Get-RequiredOctopusParameter "Project.Windows.ServiceName"
$serviceId = $displayName -replace "[^A-Za-z0-9]", ""

if ([string]::IsNullOrWhiteSpace($serviceId)) {
    throw "The Windows service name does not contain any alphanumeric characters."
}

$appPort = Get-RequiredOctopusParameter "Project.Application.Port"
$managementPort = Get-RequiredOctopusParameter "Project.Management.Port"
$jdbcUrl = Get-RequiredOctopusParameter "Project.Database.JdbcUrl"
$dbUsername = Get-RequiredOctopusParameter "Project.Database.Username"
$dbPassword = Get-RequiredOctopusParameter "Project.Database.Password"
$poolMaximumSize = Get-RequiredOctopusParameter "Project.Database.Pool.MaximumSize"
$poolMinimumIdle = Get-RequiredOctopusParameter "Project.Database.Pool.MinimumIdle"
$environmentCode = Get-RequiredOctopusParameter "Library.DurableMoney.Environment.Code"

$installDirectory = (Get-Location).Path
$appExecutable = Join-Path $installDirectory "durable-money-1-monolith.exe"
$serviceToolsDirectory = Join-Path $installDirectory "service"
$sourceWrapper = Join-Path $serviceToolsDirectory "winsw.exe"
$wrapperExecutable = Join-Path $serviceToolsDirectory "$serviceId.exe"
$wrapperConfiguration = Join-Path $serviceToolsDirectory "$serviceId.xml"
$logDirectory = Join-Path $env:ProgramData "DurableMoney\Logs\$serviceId"

if (-not (Test-Path -LiteralPath $appExecutable -PathType Leaf)) {
    $candidate = Get-ChildItem `
        -LiteralPath $installDirectory `
        -Filter "durable-money-1-monolith.exe" `
        -File `
        -Recurse |
        Select-Object -First 1

    if ($null -eq $candidate) {
        Write-Host "Package contents:"
        Get-ChildItem -LiteralPath $installDirectory -Recurse |
            Select-Object FullName

        throw "Could not find durable-money-1-monolith.exe in the package."
    }

    $appExecutable = $candidate.FullName
}

if (-not (Test-Path -LiteralPath $sourceWrapper -PathType Leaf)) {
    throw @"
WinSW was not found at:
$sourceWrapper

Publish a new Windows package using the workflow that bundles WinSW.
"@
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $serviceToolsDirectory, $logDirectory |
    Out-Null

$existingService = Get-Service -Name $serviceId -ErrorAction SilentlyContinue

if ($null -ne $existingService) {
    Write-Host "Stopping existing service '$serviceId'."

    if ($existingService.Status -ne [ServiceProcess.ServiceControllerStatus]::Stopped) {
        Stop-Service -Name $serviceId -Force

        (Get-Service -Name $serviceId).WaitForStatus(
            [ServiceProcess.ServiceControllerStatus]::Stopped,
            [TimeSpan]::FromSeconds(45)
        )
    }

    Write-Host "Removing existing service '$serviceId'."
    & sc.exe delete $serviceId | Out-Host

    $deleteDeadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 2
        $existingService = Get-Service -Name $serviceId -ErrorAction SilentlyContinue
    } while ($null -ne $existingService -and (Get-Date) -lt $deleteDeadline)

    if ($null -ne $existingService) {
        throw "Service '$serviceId' is still present after deletion."
    }
}

Copy-Item `
    -LiteralPath $sourceWrapper `
    -Destination $wrapperExecutable `
    -Force

$serviceIdXml = ConvertTo-XmlText $serviceId
$displayNameXml = ConvertTo-XmlText $displayName
$environmentCodeXml = ConvertTo-XmlText $environmentCode
$appExecutableXml = ConvertTo-XmlText $appExecutable
$installDirectoryXml = ConvertTo-XmlText $installDirectory
$logDirectoryXml = ConvertTo-XmlText $logDirectory
$appPortXml = ConvertTo-XmlText $appPort
$managementPortXml = ConvertTo-XmlText $managementPort
$jdbcUrlXml = ConvertTo-XmlText $jdbcUrl
$dbUsernameXml = ConvertTo-XmlText $dbUsername
$dbPasswordXml = ConvertTo-XmlText $dbPassword
$poolMaximumSizeXml = ConvertTo-XmlText $poolMaximumSize
$poolMinimumIdleXml = ConvertTo-XmlText $poolMinimumIdle

$configurationXml = @"
<service>
  <id>$serviceIdXml</id>
  <name>$displayNameXml</name>
  <description>Durable Money Monolith ($environmentCodeXml)</description>

  <executable>$appExecutableXml</executable>
  <workingdirectory>$installDirectoryXml</workingdirectory>

  <env name="PORT" value="$appPortXml" />
  <env name="MANAGEMENT_PORT" value="$managementPortXml" />
  <env name="SPRING_DATASOURCE_URL" value="$jdbcUrlXml" />
  <env name="DB_USER" value="$dbUsernameXml" />
  <env name="DB_PASS" value="$dbPasswordXml" />
  <env name="SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE" value="$poolMaximumSizeXml" />
  <env name="SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE" value="$poolMinimumIdleXml" />

  <startmode>Automatic</startmode>
  <delayedAutoStart>true</delayedAutoStart>
  <hidewindow>true</hidewindow>
  <stoptimeout>30 sec</stoptimeout>

  <onfailure action="restart" delay="5 sec" />
  <resetfailure>1 hour</resetfailure>

  <logpath>$logDirectoryXml</logpath>
  <log mode="roll" />

  <serviceaccount>
    <username>LocalSystem</username>
  </serviceaccount>
</service>
"@

[IO.File]::WriteAllText(
    $wrapperConfiguration,
    $configurationXml,
    (New-Object Text.UTF8Encoding($false))
)

# The XML contains the database password. Restrict it to LocalSystem and
# local administrators without writing the password to the task log.
& icacls.exe `
    $wrapperConfiguration `
    "/inheritance:r" `
    "/grant:r" `
    "*S-1-5-18:(F)" `
    "*S-1-5-32-544:(F)" |
    Out-Null

Write-Host "Installing Windows service."
Write-Host "Service ID: $serviceId"
Write-Host "Display name: $displayName"
Write-Host "Application directory: $installDirectory"
Write-Host "Application port: $appPort"

& $wrapperExecutable install

if ($LASTEXITCODE -ne 0) {
    throw "WinSW service installation failed with exit code $LASTEXITCODE."
}

Start-Service -Name $serviceId

(Get-Service -Name $serviceId).WaitForStatus(
    [ServiceProcess.ServiceControllerStatus]::Running,
    [TimeSpan]::FromSeconds(45)
)

$healthUrl = "http://127.0.0.1:$appPort/accounts"
$healthy = $false

Write-Host "Waiting for $healthUrl"

for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
        $response = Invoke-WebRequest `
            -Uri $healthUrl `
            -UseBasicParsing `
            -TimeoutSec 10

        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            $healthy = $true
            break
        }
    }
    catch {
        Write-Host "Health check attempt $attempt failed; retrying."
    }

    Start-Sleep -Seconds 3
}

if (-not $healthy) {
    Write-Host "Service status:"
    Get-Service -Name $serviceId |
        Format-List Name, DisplayName, Status

    Write-Host "Recent WinSW logs:"
    Get-ChildItem `
        -LiteralPath $logDirectory `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5 |
        ForEach-Object {
            Write-Host "----- $($_.FullName) -----"
            Get-Content `
                -LiteralPath $_.FullName `
                -Tail 100 `
                -ErrorAction SilentlyContinue
        }

    throw "The application did not become healthy at $healthUrl."
}

Write-Host "Windows application is healthy."

Get-Service -Name $serviceId |
    Format-List Name, DisplayName, Status, StartType
