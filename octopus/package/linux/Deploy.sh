#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This deployment must run as root to configure systemd."
  echo "Current user: $(id -un)"
  exit 1
fi

get_required_octopus_variable() {
  local name="$1"
  local value

  value="$(get_octopusvariable "$name")"

  if [[ -z "$value" ]]; then
    echo "Required Octopus variable '$name' is empty or missing."
    exit 1
  fi

  printf '%s' "$value"
}

write_environment_value() {
  local key="$1"
  local value="$2"

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    echo "Environment value '$key' contains a newline, which is not supported."
    exit 1
  fi

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"

  printf '%s="%s"\n' "$key" "$value"
}

SERVICE_NAME="$(get_required_octopus_variable "Project.Linux.ServiceName")"
APP_PORT="$(get_required_octopus_variable "Project.Application.Port")"
MANAGEMENT_PORT="$(get_required_octopus_variable "Project.Management.Port")"
JDBC_URL="$(get_required_octopus_variable "Project.Database.JdbcUrl")"
DB_USERNAME="$(get_required_octopus_variable "Project.Database.Username")"
DB_PASSWORD="$(get_required_octopus_variable "Project.Database.Password")"
POOL_MAXIMUM_SIZE="$(get_required_octopus_variable "Project.Database.Pool.MaximumSize")"
POOL_MINIMUM_IDLE="$(get_required_octopus_variable "Project.Database.Pool.MinimumIdle")"
ENVIRONMENT_CODE="$(get_required_octopus_variable "Library.DurableMoney.Environment.Code")"

INSTALL_DIR="$(pwd -P)"
EXECUTABLE="${INSTALL_DIR}/bin/durable-money-1-monolith"
ENVIRONMENT_DIRECTORY="/etc/durable-money"
ENVIRONMENT_FILE="${ENVIRONMENT_DIRECTORY}/${SERVICE_NAME}.env"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "Deploying Linux application"
echo "Service: ${SERVICE_NAME}"
echo "Installation directory: ${INSTALL_DIR}"
echo "Application port: ${APP_PORT}"

if [[ ! -f "${EXECUTABLE}" ]]; then
  echo "Application launcher was not found:"
  echo "${EXECUTABLE}"
  echo "Package contents:"
  find "${INSTALL_DIR}" -maxdepth 3 -type f | sort
  exit 1
fi

chmod 0755 "${EXECUTABLE}"
install -d -m 0700 "${ENVIRONMENT_DIRECTORY}"

{
  write_environment_value "PORT" "${APP_PORT}"
  write_environment_value "MANAGEMENT_PORT" "${MANAGEMENT_PORT}"
  write_environment_value "SPRING_DATASOURCE_URL" "${JDBC_URL}"
  write_environment_value "DB_USER" "${DB_USERNAME}"
  write_environment_value "DB_PASS" "${DB_PASSWORD}"
  write_environment_value \
    "SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE" \
    "${POOL_MAXIMUM_SIZE}"
  write_environment_value \
    "SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE" \
    "${POOL_MINIMUM_IDLE}"
} > "${ENVIRONMENT_FILE}"

chmod 0600 "${ENVIRONMENT_FILE}"

cat > "${UNIT_FILE}" <<UNIT
[Unit]
Description=Durable Money Monolith (${ENVIRONMENT_CODE})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${ENVIRONMENT_FILE}
ExecStart=${EXECUTABLE}

Restart=on-failure
RestartSec=5
TimeoutStopSec=30
SuccessExitStatus=143

StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
UNIT

chmod 0644 "${UNIT_FILE}"

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

echo "Waiting for the application to become available..."

if ! curl \
  --fail \
  --silent \
  --show-error \
  --retry 30 \
  --retry-delay 3 \
  --retry-all-errors \
  "http://127.0.0.1:${APP_PORT}/accounts" \
  > /dev/null
then
  echo "The application did not become healthy."
  systemctl --no-pager --full status "${SERVICE_NAME}.service" || true
  journalctl --unit "${SERVICE_NAME}.service" --no-pager --lines 200 || true
  exit 1
fi

echo "The application is healthy."
systemctl --no-pager --full status "${SERVICE_NAME}.service"
