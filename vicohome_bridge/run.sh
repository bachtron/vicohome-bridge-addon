#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# Load bashio library
source /usr/lib/bashio/bashio.sh

# ==========================
#  Config from options.json
# ==========================
EMAIL=$(bashio::config 'email')
PASSWORD=$(bashio::config 'password')
POLL_INTERVAL=$(bashio::config 'poll_interval')
LOG_LEVEL=$(bashio::config 'log_level')
BASE_TOPIC=$(bashio::config 'base_topic')

# Defaults
[ -z "${POLL_INTERVAL}" ] && POLL_INTERVAL=60
[ -z "${LOG_LEVEL}" ] && LOG_LEVEL="info"
[ -z "${BASE_TOPIC}" ] && BASE_TOPIC="vicohome"

if [ -z "${EMAIL}" ] || [ -z "${PASSWORD}" ]; then
  bashio::log.error "You must set 'email' and 'password' in the add-on configuration."
  exit 1
fi

# ==========================
#  MQTT service discovery
# ==========================
if ! bashio::services.available "mqtt"; then
  bashio::log.error "MQTT service not available. Make sure the MQTT integration/add-on is set up."
  exit 1
fi

MQTT_HOST=$(bashio::services mqtt "host")
MQTT_PORT=$(bashio::services mqtt "port")
MQTT_USERNAME=$(bashio::services mqtt "username")
MQTT_PASSWORD=$(bashio::services mqtt "password")

# Build a common argument string for mosquitto_pub
MQTT_ARGS="-h ${MQTT_HOST} -p ${MQTT_PORT}"
if [ -n "${MQTT_USERNAME}" ] && [ "${MQTT_USERNAME}" != "null" ]; then
  MQTT_ARGS="${MQTT_ARGS} -u ${MQTT_USERNAME} -P ${MQTT_PASSWORD}"
fi

bashio::log.info "Using MQTT broker at ${MQTT_HOST}:${MQTT_PORT}, base topic: ${BASE_TOPIC}"

# ==========================
#  Environment for vico-cli
# ==========================
export VICOHOME_EMAIL="${EMAIL}"
export VICOHOME_PASSWORD="${PASSWORD}"

# Ensure /data exists for persistence (it should in HA add-ons)
mkdir -p /data

# ==========================
#  Helper functions
# ==========================

# Sanitize a string to be a safe ID for topics/unique_ids
sanitize_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g'
}

# Publish MQTT discovery config for a camera (only once)
ensure_discovery_published() {
  local camera_id="$1"
  local camera_name="$2"

  local safe_id
  safe_id=$(sanitize_id "${camera_id}")

  local marker="/data/cameras_seen_${safe_id}"
  if [ -f "${marker}" ]; then
    return 0
  fi

  touch "${marker}"

  local device_ident="vicohome_camera_${safe_id}"
  local state_topic="${BASE_TOPIC}/${safe_id}/state"
  local motion_topic="${BASE_TOPIC}/${safe_id}/motion"

  local sensor_topic="homeassistant/sensor/${device_ident}_last_event/config"
  local motion_config_topic="homeassistant/binary_sensor/${device_ident}_motion/config"

  # Fallback name if empty
  if [ -z "${camera_name}" ] || [ "${camera_name}" = "null" ]; then
    camera_name="Camera ${camera_id}"
  fi

  # JSON payload for last_event sensor
  local sensor_payload
  sensor_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Last Event","unique_id":"${device_ident}_last_event","state_topic":"${state_topic}","value_template":"{{ value_json.type }}","json_attributes_topic":"${state_topic}","device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # JSON payload for motion binary_sensor
  local motion_payload
  motion_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Motion","unique_id":"${device_ident}_motion","state_topic":"${motion_topic}","device_class":"motion","payload_on":"ON","payload_off":"OFF","expire_after":30,"device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # Publish discovery configs
  mosquitto_pub ${MQTT_ARGS} -t "${sensor_topic}" -m "${sensor_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for sensor ${device_ident}_last_event"

  mosquitto_pub ${MQTT_ARGS} -t "${motion_config_topic}" -m "${motion_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for binary_sensor ${device_ident}_motion"
}

# Publish a single JSON event to per-camera topics
publish_event_for_camera() {
  local camera_safe_id="$1"
  local event_json="$2"

  # Raw events topic
  mosquitto_pub ${MQTT_ARGS} \
    -t "${BASE_TOPIC}/${camera_safe_id}/events" \
    -m "${event_json}" \
    -q 0 || bashio::log.warning "Failed to publish MQTT message for ${BASE_TOPIC}/${camera_safe_id}/events"

  # State topic (used by the sensor)
  mosquitto_pub ${MQTT_ARGS} \
    -t "${BASE_TOPIC}/${camera_safe_id}/state" \
    -m "${event_json}" \
    -q 0 || bashio::log.warning "Failed to publish MQTT message for ${BASE_TOPIC}/${camera_safe_id}/state"
}

# Publish motion pulse (ON then OFF after 5s)
publish_motion_pulse() {
  local camera_safe_id="$1"
  local motion_topic="${BASE_TOPIC}/${camera_safe_id}/motion"

  mosquitto_pub ${MQTT_ARGS} \
    -t "${motion_topic}" \
    -m "ON" \
    -q 0 || bashio::log.warning "Failed to publish motion ON for ${motion_topic}"

  # Turn OFF after a short delay so it behaves like a pulse
  (
    sleep 5
    mosquitto_pub ${MQTT_ARGS} \
      -t "${motion_topic}" \
      -m "OFF" \
      -q 0 || bashio::log.warning "Failed to publish motion OFF for ${motion_topic}"
  ) &
}

bashio::log.info "Starting Vicohome Bridge: polling every ${POLL_INTERVAL}s"

# ==========================
#  Main loop
# ==========================
while true; do
  bashio::log.debug "Running vico-cli events list --format json"

  JSON_OUTPUT=$(/usr/local/bin/vico-cli events list --format json 2>/tmp/vico_error.log)
  EXIT_CODE=$?

  if [ ${EXIT_CODE} -ne 0 ] || [ -z "${JSON_OUTPUT}" ]; then
    bashio::log.warning "vico-cli failed or returned empty data (exit ${EXIT_CODE}). See /tmp/vico_error.log"
  else
    # Expecting an array of events; stream each as individual JSON
    echo "${JSON_OUTPUT}" | jq -c '.[]' | while read -r event; do
      # Try a few common keys to get camera ID
      CAMERA_ID=$(echo "${event}" | jq -r '.camera_id // .camera.uuid // .cameraId // .device_id // .deviceId // empty')
      if [ -z "${CAMERA_ID}" ] || [ "${CAMERA_ID}" = "null" ]; then
        bashio::log.debug "Event without camera_id/device_id, skipping"
        continue
      fi

      CAMERA_NAME=$(echo "${event}" | jq -r '.camera_name // .camera.name // .cameraName // .title // empty')
      EVENT_TYPE=$(echo "${event}" | jq -r '.type // .event_type // .eventType // empty')

      SAFE_ID=$(sanitize_id "${CAMERA_ID}")

      # Ensure discovery is published once per camera
      ensure_discovery_published "${CAMERA_ID}" "${CAMERA_NAME}"

      # Publish event JSON to per-camera topics
      publish_event_for_camera "${SAFE_ID}" "${event}"

      # If it's a motion/person event, also send a motion pulse
      if [ "${EVENT_TYPE}" = "motion" ] || [ "${EVENT_TYPE}" = "person" ] || [ "${EVENT_TYPE}" = "human" ]; then
        publish_motion_pulse "${SAFE_ID}"
      fi
    done
  fi

  sleep "${POLL_INTERVAL}"
done