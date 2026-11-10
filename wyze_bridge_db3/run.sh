#!/command/with-contenv bashio
# Map Home Assistant options onto the environment variables documented by
# docker-wyze-bridge v4.5.0, then exec the bridge. Option values are never
# written to the log.
set -euo pipefail

log_info() {
  if declare -F bashio::log.info >/dev/null 2>&1; then
    bashio::log.info "$1"
  else
    printf '%s\n' "$1"
  fi
}

log_error() {
  if declare -F bashio::log.error >/dev/null 2>&1; then
    bashio::log.error "$1"
  else
    printf '%s\n' "$1" >&2
  fi
}

fail() {
  log_error "$1"
  exit 1
}

OPTIONS="${OPTIONS_JSON:-/data/options.json}"

if [[ ! -f "${OPTIONS}" ]]; then
  fail "Not configured. Save the app options, then start it. No bridge process was started."
fi

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is missing from the image. No bridge process was started."
fi

# Assign a JSON string to a shell variable in this process. Call it directly,
# not inside $(), so a missing value can exit the script.
require_string() {
  local key="$1"
  local dest="$2"
  local value
  if ! value="$(jq -er --arg key "${key}" '
    if has($key) and (.[$key] | type == "string") and (.[$key] | length > 0)
    then .[$key]
    else empty
    end
  ' "${OPTIONS}" 2>/dev/null)"; then
    fail "Not configured: ${key} is empty. Set it on the Configuration tab. No bridge process was started."
  fi
  printf -v "${dest}" '%s' "${value}"
}

optional_string() {
  local key="$1"
  local dest="$2"
  local value
  value="$(jq -r --arg key "${key}" '
    if has($key) and (.[$key] | type == "string") then .[$key] else "" end
  ' "${OPTIONS}" 2>/dev/null)"
  printf -v "${dest}" '%s' "${value}"
}

require_string wyze_email wyze_email
require_string wyze_password wyze_password
require_string wyze_api_id wyze_api_id
require_string wyze_api_key wyze_api_key
optional_string wyze_totp_key wyze_totp_key
require_string web_username web_username
require_string web_password web_password
require_string rtsp_username rtsp_username
require_string rtsp_password rtsp_password
require_string filter_names filter_names

case "${rtsp_username}" in
  *[:@\|]*)
    fail "rtsp_username cannot contain ':', '@', or '|'. Those characters are separators in STREAM_AUTH. No bridge process was started."
    ;;
esac
case "${rtsp_password}" in
  *[@\|]*)
    fail "rtsp_password cannot contain '@' or '|'. Those characters are separators in STREAM_AUTH. No bridge process was started."
    ;;
esac
if ((${#rtsp_username} < 8)); then
  fail "rtsp_username must be at least 8 characters. No bridge process was started."
fi
if ((${#rtsp_password} < 16)); then
  fail "rtsp_password must be at least 16 characters. No bridge process was started."
fi
# Comma-separated exact nicknames. Empty segments are refused. The bridge
# uppercases and trims each name, then keeps only exact matches. A list
# that matches nothing does not fall open to the rest of the account.
# read -ra drops a trailing empty field, so split by hand.
filter_parts=()
filter_rest="${filter_names}"
while true; do
  if [[ "${filter_rest}" != *","* ]]; then
    filter_parts+=("${filter_rest}")
    break
  fi
  filter_parts+=("${filter_rest%%,*}")
  filter_rest="${filter_rest#*,}"
  if [[ -z "${filter_rest}" ]]; then
    filter_parts+=("")
    break
  fi
done
if ((${#filter_parts[@]} == 0)); then
  fail "filter_names is empty. No bridge process was started."
fi
for part in "${filter_parts[@]}"; do
  trimmed="${part#"${part%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  if [[ -z "${trimmed}" ]]; then
    fail "filter_names has an empty camera nickname. No bridge process was started."
  fi
done

# Host network has no docker port map. Choose listeners before the bridge
# starts. WYZE_RTSP_BIND_IP is a test hook, not a saved app option.
# Production RTSP stays on 192.168.1.70. Loopback, 0.0.0.0, link-local,
# and 172.30.32.0/23 are still refused below.
is_safe_rtsp_ipv4() {
  local ip="$1"
  [[ "${ip}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  local a="${BASH_REMATCH[1]}" b="${BASH_REMATCH[2]}" c="${BASH_REMATCH[3]}" d="${BASH_REMATCH[4]}"
  local n
  for n in "${a}" "${b}" "${c}" "${d}"; do
    if ((10#${n} > 255)); then
      return 1
    fi
  done
  if ((10#${a} == 0 && 10#${b} == 0 && 10#${c} == 0 && 10#${d} == 0)); then
    return 1
  fi
  if ((10#${a} == 127)); then
    return 1
  fi
  if ((10#${a} == 169 && 10#${b} == 254)); then
    return 1
  fi
  if ((10#${a} == 172 && 10#${b} == 30 && (10#${c} == 32 || 10#${c} == 33))); then
    return 1
  fi
  return 0
}

ingress_gateway_present() {
  command -v ip >/dev/null 2>&1 || return 1
  ip -4 -o addr show | awk '{split($4, a, "/"); if (a[1] == "172.30.32.1") found = 1} END {exit !found}'
}

rtsp_address_present() {
  local want="$1"
  command -v ip >/dev/null 2>&1 || return 1
  ip -4 -o addr show | awk -v want="${want}" '{split($4, a, "/"); if (a[1] == want) found = 1} END {exit !found}'
}

rtsp_ip="${WYZE_RTSP_BIND_IP:-192.168.1.70}"
if [[ -z "${WYZE_RTSP_BIND_IP:-}" ]]; then
  if ! command -v ip >/dev/null 2>&1; then
    fail "iproute2 is missing. No bridge process was started."
  fi
  if ! ingress_gateway_present; then
    fail "172.30.32.1 is not a local address, so ingress cannot reach the WebUI. No bridge process was started."
  fi
  if ! rtsp_address_present "${rtsp_ip}"; then
    fail "192.168.1.70 is not a local address. RTSP was not moved to another interface. No bridge process was started."
  fi
fi
if ! is_safe_rtsp_ipv4 "${rtsp_ip}"; then
  fail "RTSP would not be bound to one LAN IPv4 on port 8554. Loopback, 0.0.0.0, link-local, and 172.30.32.0/23 are refused. No bridge process was started."
fi

export WYZE_EMAIL="${wyze_email}"
export WYZE_PASSWORD="${wyze_password}"
export WYZE_API_ID="${wyze_api_id}"
export WYZE_API_KEY="${wyze_api_key}"
if [[ -n "${wyze_totp_key}" ]]; then
  export WYZE_TOTP_KEY="${wyze_totp_key}"
else
  unset WYZE_TOTP_KEY
fi
export BRIDGE_AUTH=true
export BRIDGE_USERNAME="${web_username}"
export BRIDGE_PASSWORD="${web_password}"
export STREAM_AUTH="${rtsp_username}:${rtsp_password}"
export FILTER_NAMES="${filter_names}"
export FILTER_BLOCKS=false
export WYZE_RTSP_LISTEN="${rtsp_ip}:8554"
export BRIDGE_LISTEN_HOST="172.30.32.1"
export BRIDGE_PORT=5080
export GWELL_ENABLED=false
export MQTT_ENABLED=false
unset MQTT_HOST MQTT_USERNAME MQTT_PASSWORD
export LOG_LEVEL=info
export RECORD_ALL=false
export SNAPSHOT_INTERVAL=0
# WYZE_STATE_DIR is only for the local startup test. The app does not set it.
if [[ -n "${WYZE_STATE_DIR:-}" ]]; then
  export STATE_DIR="${WYZE_STATE_DIR}"
else
  export STATE_DIR=/data/wyze-bridge-state
fi
mkdir -p "${STATE_DIR}"

unset wyze_email wyze_password wyze_api_id wyze_api_key wyze_totp_key
unset web_username web_password rtsp_username rtsp_password

log_info "Starting wyze-bridge. Camera filter is an exact nickname list. Web UI is ingress plus basic auth on 172.30.32.1:5080. Internal shim is 127.0.0.1:5080. RTSP auth is on ${WYZE_RTSP_LISTEN}. go2rtc API is 127.0.0.1:1984 only. WebRTC server ports are off. MQTT and Gwell are off."

BIN="${WYZE_BRIDGE_BIN:-/usr/local/bin/wyze-bridge}"
if [[ ! -x "${BIN}" ]]; then
  fail "Bridge binary is not executable. No bridge process was started."
fi
exec "${BIN}"
