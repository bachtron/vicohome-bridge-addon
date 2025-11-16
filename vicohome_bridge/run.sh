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

bashio::log.info "Vicohome Bridge configuration:"
bashio::log.info "  poll_interval = ${POLL_INTERVAL}s"
bashio::log.info "  base_topic    = ${BASE_TOPIC}"
bashio::log.info "  log_level     = ${LOG_LEVEL}"

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
export VICOHOME_DEBUG="1"

mkdir -p /data

# ==========================
#  Helper functions
# ==========================

sanitize_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g'
}

# Publish status JSON for one device (battery, wifi, ip, status)
publish_status_for_device() {
  local camera_id="$1"
  local battery="$2"
  local signal="$3"
  local ip="$4"

  local safe_id
  safe_id=$(sanitize_id "${camera_id}")

  [ -z "${battery}" ] || [ "${battery}" = "null" ] && battery=0
  [ -z "${signal}" ] || [ "${signal}" = "null" ] && signal=0
  [ -z "${ip}" ] || [ "${ip}" = "null" ] && ip=""

  local online="offline"
  if [ -n "${ip}" ]; then
    online="online"
  fi

  local status_topic="${BASE_TOPIC}/${safe_id}/status"
  local payload
  payload=$(cat <<EOF
{"batteryLevel":${battery},"signalStrength":${signal},"ip":"${ip}","status":"${online}"}
EOF
)

  mosquitto_pub ${MQTT_ARGS} -t "${status_topic}" -m "${payload}" -q 0 \
    || bashio::log.warning "Failed to publish status for ${camera_id}"
}

# Always publish full MQTT discovery for a camera (no marker / no skipping)
ensure_discovery_published() {
  local camera_id="$1"
  local camera_name="$2"

  local safe_id
  safe_id=$(sanitize_id "${camera_id}")

  local device_ident="vicohome_camera_v3_${safe_id}"
  local state_topic="${BASE_TOPIC}/${safe_id}/state"
  local motion_topic="${BASE_TOPIC}/${safe_id}/motion"
  local status_topic="${BASE_TOPIC}/${safe_id}/status"

  local sensor_topic="homeassistant/sensor/${device_ident}_last_event/config"
  local motion_config_topic="homeassistant/binary_sensor/${device_ident}_motion/config"
  local battery_config_topic="homeassistant/sensor/${device_ident}_battery/config"
  local wifi_config_topic="homeassistant/sensor/${device_ident}_wifi/config"
  local online_config_topic="homeassistant/binary_sensor/${device_ident}_online/config"

  if [ -z "${camera_name}" ] || [ "${camera_name}" = "null" ]; then
    camera_name="Camera ${camera_id}"
  fi

  # Last Event sensor
  local sensor_payload
  sensor_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Last Event","unique_id":"${device_ident}_last_event","state_topic":"${state_topic}","value_template":"{{ value_json.eventType or value_json.type }}","json_attributes_topic":"${state_topic}","device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # Motion binary sensor
  local motion_payload
  motion_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Motion","unique_id":"${device_ident}_motion","state_topic":"${motion_topic}","device_class":"motion","payload_on":"ON","payload_off":"OFF","expire_after":30,"device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # Battery sensor
  local battery_payload
  battery_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Battery","unique_id":"${device_ident}_battery","state_topic":"${status_topic}","unit_of_measurement":"%","device_class":"battery","value_template":"{{ value_json.batteryLevel }}","device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # Wi-Fi signal sensor
  local wifi_payload
  wifi_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} WiFi","unique_id":"${device_ident}_wifi","state_topic":"${status_topic}","unit_of_measurement":"dBm","icon":"mdi:wifi","value_template":"{{ value_json.signalStrength }}","device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  # Online status binary_sensor
  local online_payload
  online_payload=$(cat <<EOF
{"name":"Vicohome ${camera_name} Online","unique_id":"${device_ident}_online","state_topic":"${status_topic}","device_class":"connectivity","payload_on":"online","payload_off":"offline","value_template":"{{ value_json.status }}","device":{"identifiers":["${device_ident}"],"name":"Vicohome ${camera_name}","manufacturer":"Vicohome","model":"Camera"}}
EOF
)

  mosquitto_pub ${MQTT_ARGS} -t "${sensor_topic}" -m "${sensor_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for sensor ${device_ident}_last_event"

  mosquitto_pub ${MQTT_ARGS} -t "${motion_config_topic}" -m "${motion_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for binary_sensor ${device_ident}_motion"

  mosquitto_pub ${MQTT_ARGS} -t "${battery_config_topic}" -m "${battery_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for sensor ${device_ident}_battery"

  mosquitto_pub ${MQTT_ARGS} -t "${wifi_config_topic}" -m "${wifi_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for sensor ${device_ident}_wifi"

  mosquitto_pub ${MQTT_ARGS} -t "${online_config_topic}" -m "${online_payload}" -q 0 || \
    bashio::log.warning "Failed to publish MQTT discovery config for binary_sensor ${device_ident}_online"
}

publish_event_for_camera() {
  local camera_safe_id="$1"
  local event_json="$2"

  mosquitto_pub ${MQTT_ARGS} \
    -t "${BASE_TOPIC}/${camera_safe_id}/events" \
    -m "${event_json}" \
    -q 0 || bashio::log.warning "Failed to publish MQTT message for ${BASE_TOPIC}/${camera_safe_id}/events"

  mosquitto_pub ${MQTT_ARGS} \
    -t "${BASE_TOPIC}/${camera_safe_id}/state" \
    -m "${event_json}" \
    -q 0 || bashio::log.warning "Failed to publish MQTT message for ${BASE_TOPIC}/${camera_safe_id}/state"
}

publish_motion_pulse() {
  local camera_safe_id="$1"
  local motion_topic="${BASE_TOPIC}/${camera_safe_id}/motion"

  mosquitto_pub ${MQTT_ARGS} \
    -t "${motion_topic}" \
    -m "ON" \
    -q 0 || bashio::log.warning "Failed to publish motion ON for ${motion_topic}"

  (
    sleep 5
    mosquitto_pub ${MQTT_ARGS} \
      -t "${motion_topic}" \
      -m "OFF" \
      -q 0 || bashio::log.warning "Failed to publish motion OFF for ${motion_topic}"
  ) &
}

# Refresh device status for all cameras (battery/wifi/online)
refresh_device_status() {
  bashio::log.info "Refreshing Vicohome device status (battery/wifi/online)..."

  local DEVICES_JSON
  DEVICES_JSON=$(/usr/local/bin/vico-cli devices list --format json 2>/tmp/vico_devices_error.log)
  local DEV_EXIT=$?

  if [ ${DEV_EXIT} -ne 0 ]; then
    bashio::log.warning "vico-cli devices list (status refresh) failed (exit ${DEV_EXIT}). stderr (first 200 chars): $(head-c 200 /tmp/vico_devices_error.log 2>/dev/null)"
    return
  fi

  if [ -z "${DEVICES_JSON}" ] || [ "${DEVICES_JSON}" = "null" ]; then
    bashio::log.info "vico-cli devices list (status refresh) returned empty/null."
    return
  fi

  local dev_first_char
  dev_first_char=$(printf '%s' "${DEVICES_JSON}" | sed -n '1s/^\(.\).*$/\1/p')

  if [ "${dev_first_char}" = "[" ]; then
    echo "${DEVICES_JSON}" | jq -c '.[]' | while read -r dev; do
      local DEV_ID BATTERY SIGNAL IP DEV_NAME
      DEV_ID=$(echo "${dev}" | jq -r '.serialNumber // .deviceId // .device_id // .id // empty')
      [ -z "${DEV_ID}" ] || [ "${DEV_ID}" = "null" ] && continue
      DEV_NAME=$(echo "${dev}" | jq -r '.deviceName // .name // .nickname // empty')
      BATTERY=$(echo "${dev}" | jq -r '.batteryLevel // 0')
      SIGNAL=$(echo "${dev}" | jq -r '.signalStrength // 0')
      IP=$(echo "${dev}" | jq -r '.ip // ""')

      ensure_discovery_published "${DEV_ID}" "${DEV_NAME}"
      publish_status_for_device "${DEV_ID}" "${BATTERY}" "${SIGNAL}" "${IP}"
    done
  else
    local dev DEV_ID BATTERY SIGNAL IP DEV_NAME
    dev="${DEVICES_JSON}"
    DEV_ID=$(echo "${dev}" | jq -r '.serialNumber // .deviceId // .device_id // .id // empty')
    [ -z "${DEV_ID}" ] || [ "${DEV_ID}" = "null" ] && return
    DEV_NAME=$(echo "${dev}" | jq -r '.deviceName // .name // .nickname // empty')
    BATTERY=$(echo "${dev}" | jq -r '.batteryLevel // 0')
    SIGNAL=$(echo "${dev}" | jq -r '.signalStrength // 0')
    IP=$(echo "${dev}" | jq -r '.ip // ""')

    ensure_discovery_published "${DEV_ID}" "${DEV_NAME}"
    publish_status_for_device "${DEV_ID}" "${BATTERY}" "${SIGNAL}" "${IP}"
  fi
}

# ==========================
#  Initial device discovery
# ==========================
bashio::log.info "Running initial device discovery & status refresh..."
refresh_device_status

bashio::log.info "Starting Vicohome Bridge main loop: polling every ${POLL_INTERVAL}s"

# ==========================
#  Main loop
# ==========================
while true; do
  # Refresh battery/wifi/online each loop
  refresh_device_status

  bashio::log.info "Polling vico-cli for events..."

  JSON_OUTPUT=$(/usr/local/bin/vico-cli events list --format json 2>/tmp/vico_error.log)
  EXIT_CODE=$?

  if [ ${EXIT_CODE} -ne 0 ]; then
    bashio::log.error "vico-cli exited with code ${EXIT_CODE}."
    bashio::log.error "vico-cli stderr (first 300 chars): $(head -c 300 /tmp/vico_error.log 2>/dev/null)"
    sleep "${POLL_INTERVAL}"
    continue
  fi

  if [ -z "${JSON_OUTPUT}" ] || [ "${JSON_OUTPUT}" = "null" ]; then
    bashio::log.info "vico-cli returned empty or null output (no events or non-JSON)."
    sleep "${POLL_INTERVAL}"
    continue
  fi

  bashio::log.info "vico-cli output (first 200 chars): $(echo "${JSON_OUTPUT}" | head -c 200)"

  first_char=$(printf '%s' "${JSON_OUTPUT}" | sed -n '1s/^\(.\).*$/\1/p')
  if [ "${first_char}" != "[" ] && [ "${first_char}" != "{" ]; then
    bashio::log.info "vico-cli output does not look like JSON (starts with '${first_char}'), skipping parse this cycle."
    sleep "${POLL_INTERVAL}"
    continue
  fi

  if echo "${JSON_OUTPUT}" | jq -e 'type=="array"' >/dev/null 2>&1; then
    echo "${JSON_OUTPUT}" | jq -c '.[]' | while read -r event; do
      CAMERA_ID=$(echo "${event}" | jq -r '.serialNumber // .deviceId // .device_id // .camera_id // .camera.uuid // .cameraId // empty')
      if [ -z "${CAMERA_ID}" ] || [ "${CAMERA_ID}" = "null" ]; then
        bashio::log.info "Event without camera/device ID, skipping. Event snippet: $(echo "${event}" | head -c 120)"
        continue
      fi

      CAMERA_NAME=$(echo "${event}" | jq -r '.deviceName // .camera_name // .camera.name // .cameraName // .title // empty')
      EVENT_TYPE=$(echo "${event}" | jq -r '.eventType // .type // .event_type // empty')

      SAFE_ID=$(sanitize_id "${CAMERA_ID}")

      ensure_discovery_published "${CAMERA_ID}" "${CAMERA_NAME}"
      publish_event_for_camera "${SAFE_ID}" "${event}"

      if [ "${EVENT_TYPE}" = "motion" ] || [ "${EVENT_TYPE}" = "person" ] || [ "${EVENT_TYPE}" = "human" ] || [ "${EVENT_TYPE}" = "bird" ]; then
        publish_motion_pulse "${SAFE_ID}"
      fi
    done
  else
    event="${JSON_OUTPUT}"

    CAMERA_ID=$(echo "${event}" | jq -r '.serialNumber // .deviceId // .device_id // .camera_id // .camera.uuid // .cameraId // empty')
    if [ -z "${CAMERA_ID}" ] || [ "${CAMERA_ID}" = "null" ]; then
      bashio::log.info "Single event without camera/device ID. Event snippet: $(echo "${event}" | head -c 120)"
      sleep "${POLL_INTERVAL}"
      continue
    fi

    CAMERA_NAME=$(echo "${event}" | jq -r '.deviceName // .camera_name // .camera.name // .cameraName // .title // empty')
    EVENT_TYPE=$(echo "${event}" | jq -r '.eventType // .type // .eventType // empty')

    SAFE_ID=$(sanitize_id "${CAMERA_ID}")

    ensure_discovery_published "${CAMERA_ID}" "${CAMERA_NAME}"
    publish_event_for_camera "${SAFE_ID}" "${event}"

    if [ "${EVENT_TYPE}" = "motion" ] || [ "${EVENT_TYPE}" = "person" ] || [ "${EVENT_TYPE}" = "human" ] || [ "${EVENT_TYPE}" = "bird" ]; then
      publish_motion_pulse "${SAFE_ID}"
    fi
  fi

  sleep "${POLL_INTERVAL}"
done