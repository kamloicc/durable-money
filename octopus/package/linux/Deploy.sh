#!/usr/bin/env bash

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This deployment must run as root to configure systemd."
  echo "Current user: $(id -un)"
  exit 1
fi

SERVICE_NAME="#{Project.Linux.ServiceName}"
APP_PORT="#{Project.Application.Port}"
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

cat > "${ENVIRONMENT_FILE}" <<'ENVIRONMENT'
PORT="#{Project.Application.Port}"
MANAGEMENT_PORT="#{Project.Management.Port}"
SPRING_DATASOURCE_URL="#{Project.Database.JdbcUrl}"
DB_USER="#{Project.Database.Username}"
DB_PASS="#{Project.Database.Password}"
SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE="#{Project.Database.Pool.MaximumSize}"
SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE="#{Project.Database.Pool.MinimumIdle}"
ENVIRONMENT

chmod 0600 "${ENVIRONMENT_FILE}"

cat > "${UNIT_FILE}" <<UNIT
[Unit]
Description=Durable Money Monolith (#{Library.DurableMoney.Environment.Code})
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
