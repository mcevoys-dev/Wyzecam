#!/usr/bin/env bash
# Exercise run.sh with fake option files. Dummy values stay out of the log.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="${ROOT}/wyze_bridge_db3/run.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

SECRET_EMAIL="person@example.com"
SECRET_PASSWORD="dummy-wyzepass-not-real"
SECRET_API_ID="dummy-api-id"
SECRET_API_KEY="dummy-api-key"
SECRET_WEB_USER="viewer"
SECRET_WEB_PASSWORD="dummy-webpass-not-real"
SECRET_RTSP_USER="rtspuser"
SECRET_RTSP_PASSWORD="dummy-rtsppass-not-real"

assert_absent() {
  local file="$1"
  python3 - "${file}" "${SECRET_EMAIL}" "${SECRET_PASSWORD}" "${SECRET_API_ID}" "${SECRET_API_KEY}" "${SECRET_WEB_PASSWORD}" "${SECRET_RTSP_PASSWORD}" << 'PY'
import pathlib, sys
file, *needles = sys.argv[1:]
text = pathlib.Path(file).read_text()
for needle in needles:
    if needle and needle in text:
        raise SystemExit(f"secret leaked into log: {needle}")
print("log has no dummy secrets")
PY
}

run_case() {
  local name="$1"
  local expect="$2"
  shift 2
  local log="${TMP}/${name}.log"
  set +e
  env "$@" bash "${RUN}" >"${log}" 2>&1
  local status=$?
  set -e
  if [[ "${status}" -ne "${expect}" ]]; then
    echo "${name}: exit ${status}, want ${expect}" >&2
    cat "${log}" >&2
    exit 1
  fi
  assert_absent "${log}"
  echo "${name}: exit ${status}"
}

# Missing file.
run_case missing 1 OPTIONS_JSON="${TMP}/nope.json"

# Empty object.
printf '%s\n' '{}' > "${TMP}/empty.json"
run_case empty 1 OPTIONS_JSON="${TMP}/empty.json"

# Configured. The fake bridge checks the environment and prints a fixed line.
cat > "${TMP}/fake-bridge" << 'EOF'
#!/usr/bin/env python3
import os, sys
expected = {
    "WYZE_EMAIL": os.environ["EXPECT_EMAIL"],
    "WYZE_PASSWORD": os.environ["EXPECT_PASSWORD"],
    "WYZE_API_ID": os.environ["EXPECT_API_ID"],
    "WYZE_API_KEY": os.environ["EXPECT_API_KEY"],
    "BRIDGE_USERNAME": os.environ["EXPECT_WEB_USER"],
    "BRIDGE_PASSWORD": os.environ["EXPECT_WEB_PASSWORD"],
    "STREAM_AUTH": os.environ["EXPECT_RTSP_USER"] + ":" + os.environ["EXPECT_RTSP_PASSWORD"],
}
for key, value in expected.items():
    if os.environ.get(key) != value:
        sys.exit(2)
if os.environ.get("FILTER_NAMES") != os.environ.get("EXPECT_FILTER", "Side door"):
    sys.exit(3)
if os.environ.get("FILTER_BLOCKS") != "false":
    sys.exit(4)
if os.environ.get("GWELL_ENABLED") != "false":
    sys.exit(5)
if os.environ.get("MQTT_ENABLED") != "false":
    sys.exit(6)
if "MQTT_HOST" in os.environ:
    sys.exit(7)
if os.environ.get("BRIDGE_AUTH") != "true":
    sys.exit(8)
if os.environ.get("LOG_LEVEL") != "info":
    sys.exit(9)
if os.environ.get("RECORD_ALL") != "false":
    sys.exit(10)
if os.environ.get("SNAPSHOT_INTERVAL") != "0":
    sys.exit(11)
if os.environ.get("WYZE_TOTP_KEY", "") != "":
    sys.exit(12)
if not os.path.isdir(os.environ["STATE_DIR"]):
    sys.exit(13)
if os.environ.get("WYZE_RTSP_LISTEN") != "192.0.2.10:8554":
    sys.exit(14)
if os.environ.get("BRIDGE_LISTEN_HOST") != "172.30.32.1":
    sys.exit(15)
if os.environ.get("BRIDGE_PORT") != "5080":
    sys.exit(16)
print("bridge-env-ok")
EOF
chmod 0755 "${TMP}/fake-bridge"

cat > "${TMP}/ready.json" << EOF
{
  "wyze_email": "${SECRET_EMAIL}",
  "wyze_password": "${SECRET_PASSWORD}",
  "wyze_api_id": "${SECRET_API_ID}",
  "wyze_api_key": "${SECRET_API_KEY}",
  "web_username": "${SECRET_WEB_USER}",
  "web_password": "${SECRET_WEB_PASSWORD}",
  "rtsp_username": "${SECRET_RTSP_USER}",
  "rtsp_password": "${SECRET_RTSP_PASSWORD}",
  "filter_names": "Side door"
}
EOF

run_case ready 0 \
  OPTIONS_JSON="${TMP}/ready.json" \
  WYZE_BRIDGE_BIN="${TMP}/fake-bridge" \
  WYZE_STATE_DIR="${TMP}/state-ready" \
  WYZE_RTSP_BIND_IP="192.0.2.10" \
  EXPECT_EMAIL="${SECRET_EMAIL}" \
  EXPECT_PASSWORD="${SECRET_PASSWORD}" \
  EXPECT_API_ID="${SECRET_API_ID}" \
  EXPECT_API_KEY="${SECRET_API_KEY}" \
  EXPECT_WEB_USER="${SECRET_WEB_USER}" \
  EXPECT_WEB_PASSWORD="${SECRET_WEB_PASSWORD}" \
  EXPECT_RTSP_USER="${SECRET_RTSP_USER}" \
  EXPECT_RTSP_PASSWORD="${SECRET_RTSP_PASSWORD}"
grep -q "bridge-env-ok" "${TMP}/ready.log"

python3 - "${TMP}/comma.json" << EOF
import json, pathlib
doc = json.loads(pathlib.Path("${TMP}/ready.json").read_text())
doc["filter_names"] = "Side door,Garage Rear"
pathlib.Path("${TMP}/comma.json").write_text(json.dumps(doc))
EOF
run_case comma 0 \
  OPTIONS_JSON="${TMP}/comma.json" \
  WYZE_BRIDGE_BIN="${TMP}/fake-bridge" \
  WYZE_STATE_DIR="${TMP}/state-comma" \
  WYZE_RTSP_BIND_IP="192.0.2.10" \
  EXPECT_EMAIL="${SECRET_EMAIL}" \
  EXPECT_PASSWORD="${SECRET_PASSWORD}" \
  EXPECT_API_ID="${SECRET_API_ID}" \
  EXPECT_API_KEY="${SECRET_API_KEY}" \
  EXPECT_WEB_USER="${SECRET_WEB_USER}" \
  EXPECT_WEB_PASSWORD="${SECRET_WEB_PASSWORD}" \
  EXPECT_RTSP_USER="${SECRET_RTSP_USER}" \
  EXPECT_RTSP_PASSWORD="${SECRET_RTSP_PASSWORD}" \
  EXPECT_FILTER="Side door,Garage Rear"
grep -q "bridge-env-ok" "${TMP}/comma.log"

python3 - "${TMP}/empty-name.json" << EOF
import json, pathlib
doc = json.loads(pathlib.Path("${TMP}/ready.json").read_text())
doc["filter_names"] = "Side door,"
pathlib.Path("${TMP}/empty-name.json").write_text(json.dumps(doc))
EOF
run_case emptyname 1 \
  OPTIONS_JSON="${TMP}/empty-name.json" \
  WYZE_RTSP_BIND_IP="192.0.2.10"
grep -q "empty camera nickname" "${TMP}/emptyname.log"

# Password with a colon is accepted. @ is not.
cat > "${TMP}/colon.json" << EOF
{
  "wyze_email": "${SECRET_EMAIL}",
  "wyze_password": "${SECRET_PASSWORD}",
  "wyze_api_id": "${SECRET_API_ID}",
  "wyze_api_key": "${SECRET_API_KEY}",
  "web_username": "${SECRET_WEB_USER}",
  "web_password": "${SECRET_WEB_PASSWORD}",
  "rtsp_username": "${SECRET_RTSP_USER}",
  "rtsp_password": "abc:def-extra-secret",
  "filter_names": "Side door"
}
EOF
run_case colon 0 \
  OPTIONS_JSON="${TMP}/colon.json" \
  WYZE_BRIDGE_BIN="${TMP}/fake-bridge" \
  WYZE_STATE_DIR="${TMP}/state-colon" \
  WYZE_RTSP_BIND_IP="192.0.2.10" \
  EXPECT_EMAIL="${SECRET_EMAIL}" \
  EXPECT_PASSWORD="${SECRET_PASSWORD}" \
  EXPECT_API_ID="${SECRET_API_ID}" \
  EXPECT_API_KEY="${SECRET_API_KEY}" \
  EXPECT_WEB_USER="${SECRET_WEB_USER}" \
  EXPECT_WEB_PASSWORD="${SECRET_WEB_PASSWORD}" \
  EXPECT_RTSP_USER="${SECRET_RTSP_USER}" \
  EXPECT_RTSP_PASSWORD="abc:def-extra-secret"

python3 - "${TMP}/at.json" << EOF
import json, pathlib, os
doc = json.loads(pathlib.Path("${TMP}/ready.json").read_text())
doc["rtsp_password"] = "bad@secret"
pathlib.Path("${TMP}/at.json").write_text(json.dumps(doc))
EOF
run_case atsign 1 OPTIONS_JSON="${TMP}/at.json"
grep -q "rtsp_password" "${TMP}/atsign.log"

python3 - "${TMP}/short-pass.json" << EOF
import json, pathlib
doc = json.loads(pathlib.Path("${TMP}/ready.json").read_text())
doc["rtsp_password"] = "short-pass"
pathlib.Path("${TMP}/short-pass.json").write_text(json.dumps(doc))
EOF
run_case shortpass 1 OPTIONS_JSON="${TMP}/short-pass.json"
grep -q "at least 16 characters" "${TMP}/shortpass.log"

python3 - "${TMP}/short-user.json" << EOF
import json, pathlib
doc = json.loads(pathlib.Path("${TMP}/ready.json").read_text())
doc["rtsp_username"] = "short"
pathlib.Path("${TMP}/short-user.json").write_text(json.dumps(doc))
EOF
run_case shortuser 1 OPTIONS_JSON="${TMP}/short-user.json"
grep -q "at least 8 characters" "${TMP}/shortuser.log"

for bad_ip in 127.0.0.1 0.0.0.0 172.30.32.1 172.30.33.10 169.254.1.1; do
  run_case "bind-${bad_ip}" 1 \
    OPTIONS_JSON="${TMP}/ready.json" \
    WYZE_BRIDGE_BIN="${TMP}/fake-bridge" \
    WYZE_RTSP_BIND_IP="${bad_ip}"
  grep -q "one LAN IPv4" "${TMP}/bind-${bad_ip}.log"
done

if ! command -v ip >/dev/null 2>&1; then
  run_case noip 1 \
    OPTIONS_JSON="${TMP}/ready.json" \
    WYZE_BRIDGE_BIN="${TMP}/fake-bridge"
  grep -q "iproute2 is missing" "${TMP}/noip.log"
elif ip -4 -o addr show | awk '{split($4, a, "/"); if (a[1] == "172.30.32.1") found = 1} END {exit !found}'; then
  echo "ingress gateway present; skip missing-gateway case"
else
  run_case noingress 1 \
    OPTIONS_JSON="${TMP}/ready.json" \
    WYZE_BRIDGE_BIN="${TMP}/fake-bridge"
  grep -q "172.30.32.1 is not a local address" "${TMP}/noingress.log"
fi

echo "run.sh checks passed"
