#!/usr/bin/with-contenv bashio

EMAIL=$(bashio::config 'vicohome_email')
PASSWORD=$(bashio::config 'vicohome_password')
EVENT_INDEX=$(bashio::config 'event_index')
HTTP_PORT=$(bashio::config 'http_port')
LOG_LEVEL=$(bashio::config 'log_level')

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  bashio::log.fatal "vicohome_email and vicohome_password must be set in the add-on configuration."
  exit 1
fi

export VICOHOME_EMAIL="${EMAIL}"
export VICOHOME_PASSWORD="${PASSWORD}"
export EVENT_INDEX="${EVENT_INDEX}"
export HTTP_PORT="${HTTP_PORT}"
export LOG_LEVEL="${LOG_LEVEL}"

bashio::log.info "Starting Vicohome Bridge on port ${HTTP_PORT}, using event index ${EVENT_INDEX}"

exec python3 /usr/src/app/server.py
