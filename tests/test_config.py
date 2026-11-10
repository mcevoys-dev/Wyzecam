#!/usr/bin/env python3
"""Structural checks for the app files. This is not the Supervisor schema loader."""

import hashlib
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "wyze_bridge_db3"


def main() -> None:
    config = yaml.safe_load((APP / "config.yaml").read_text())
    assert config["slug"] == "wyze_bridge_db3"
    assert config["version"] == "4.5.0-wyzedb3.6"
    assert config["boot"] == "manual"
    assert config["init"] is False
    assert config["host_network"] is True
    assert config["ingress"] is True
    assert config["ingress_port"] == 5080
    assert config["arch"] == ["amd64"]
    assert config["stage"] == "experimental"
    assert "image" not in config
    assert "services" not in config
    assert "map" not in config
    assert config["homeassistant_api"] is False
    assert config["hassio_api"] is False
    assert config["docker_api"] is False
    assert config["full_access"] is False
    assert "ports" not in config
    config_text = (APP / "config.yaml").read_text()
    for published in ("1984/tcp", "5080/tcp", "8554/tcp", "8555/tcp", "8889/tcp", "8189/udp", "18554", "18555", "11984"):
        assert published not in config_text, published
    assert config["options"] == {"filter_names": "Side door,Garage Rear"}
    schema = config["schema"]
    for key, kind in {
        "wyze_email": "email",
        "wyze_password": "password",
        "wyze_api_id": "password",
        "wyze_api_key": "password",
        "web_username": "str",
        "web_password": "password",
        "rtsp_username": "str(8,)",
        "rtsp_password": "password(16,)",
    }.items():
        assert schema[key] == kind, key
    assert schema["wyze_totp_key"] == "password?"
    assert schema["filter_names"] == r"match(^[^,\r\n]+(?:,[^,\r\n]+)*$)"
    name_re = re.compile(r"^[^,\r\n]+(?:,[^,\r\n]+)*$")
    assert name_re.match(config["options"]["filter_names"])
    assert name_re.match("Side door")
    assert not name_re.match("Side door,")
    assert not name_re.match(",Garage Rear")
    assert not name_re.match("Side door,,Garage Rear")
    # Supervisor supervisor/apps/options.py RE_SCHEMA_ELEMENT. A value that
    # misses this pattern makes the app disappear from the store.
    schema_element = re.compile(
        r"^(?:"
        r"|bool"
        r"|email"
        r"|url"
        r"|port"
        r"|device(?:\((?P<filter>subsystem=[a-z]+)\))?"
        r"|str(?:\((?P<s_min>\d+)?,(?P<s_max>\d+)?\))?"
        r"|password(?:\((?P<p_min>\d+)?,(?P<p_max>\d+)?\))?"
        r"|int(?:\((?P<i_min>-?\d+)?,(?P<i_max>-?\d+)?\))?"
        r"|float(?:\((?P<f_min>-?\d*\.?\d+)?,(?P<f_max>-?\d*\.?\d+)?\))?"
        r"|match\((?P<match>.*)\)"
        r"|list\((?P<list>.+)\)"
        r")\??$"
    )
    for key, kind in schema.items():
        assert schema_element.match(kind), f"schema {key}={kind!r} is not a Supervisor type"
    dockerfile = (APP / "Dockerfile").read_text()
    for needle in (
        "sha256:1a97fbadb2eb46ba8e4bce6b08f45bc24ef0180d1f3b3192886a080c8268ba71",
        "sha256:0648ddfa35769070197ba1cdf22a16dc452caf9315e66b91791308a543baf229",
        "sha256:02f21ef39c1c3bd70e7123b2503e3543bb8d2d703ecfd4de83288e29b7f45483",
        "sha256:ed340acf0a3a77a761b4d3ee2977ab5ddc44038304597e66b0ccfd859b8d8a1f",
        "78aa79bcedec8f155e4060a379613979b0b3ee48ff62ee5164bafc0ac6532386",
        "318b8f1e41c2ffe994b326fbfac0ccbb84718ee24ee0ea76f3fe5943d693d2db",
        "b5948cfb25404cc5cb37b166ecaa2dca20b11d4b",
        "da56b956b9bfb8f426f8c2efda71f8f2851e76b8",
        "a42e34e431e17e37e82e3bd988db43056e8b8d57",
        "GOARCH=amd64",
        "wyzedb3-a42e34e-pkg-tutk.patch",
        "strict-filter.patch",
        "host-listeners.patch",
        "4.5.0+strict-filter+hostnet+kvs",
        "kvs-ice-urls.patch",
        "iproute2",
    ):
        assert needle in dockerfile, needle
    assert "COPY --from=upstream" not in dockerfile
    assert "gwell-proxy" not in dockerfile
    strict = (APP / "patches/strict-filter.patch").read_text()
    assert "return nil" in strict
    assert "refusing to stream the unfiltered list" in strict
    assert "TestFilter_UnmatchedNameIsEmpty" in strict
    assert "TestFilter_TwoExactNames" in strict
    assert "TestFilter_PartialNameIsEmpty" in strict
    assert hashlib.sha256(strict.encode()).hexdigest() == (
        "32ab5196f1d6205c12f2d93e9a326f58012635e7feec19eab88ee312bdac97d4"
    )

    code_patch = (APP / "patches/wyzedb3-a42e34e-pkg-tutk.patch").read_bytes()
    full_patch = (APP / "patches/UPSTREAM-a42e34e.diff").read_bytes()
    assert hashlib.sha256(code_patch).hexdigest() == (
        "219f39231ca00a148c2b6f97f644812814adb9c6c718f3487435f61c5387fb91"
    )
    assert hashlib.sha256(full_patch).hexdigest() == (
        "3fc17f54dd4e526631fd3a39bdb9d202348d825259f81465d0f325cc2710de28"
    )
    assert b"internal/wyze/README.md" not in code_patch
    assert b"internal/wyze/README.md" in full_patch
    assert code_patch.count(b"diff --git") == 4
    assert full_patch.count(b"diff --git") == 5

    listeners = (APP / "patches/host-listeners.patch").read_bytes()
    listener_text = listeners.decode()
    added = "\n".join(
        line[1:]
        for line in listener_text.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )
    for needle in (
        "127.0.0.1:1984",
        "172.30.32.1:5080",
        "127.0.0.1:18554",
        "safeRTSPListen",
        '"api", "ws", "rtsp", "webrtc", "wyze"',
        'Listen: ""',
        'registerInternalRoutes',
        'JoinHostPort("127.0.0.1"',
    ):
        assert needle in added, needle
    assert '"hass"' not in added
    for unsafe in (
        'Listen: ":1984"',
        'Listen: ":8554"',
        'Listen: ":8555"',
        'Listen: ":8889"',
        'Origin: "*"',
    ):
        assert unsafe not in added, unsafe
    assert hashlib.sha256(listeners).hexdigest() == (
        "6b89affb61b8a33b522a6df70e08e5b7b68c2c64bd5ea3ffe7a3f0d247b2ade5"
    )

    kvs = (APP / "patches/kvs-ice-urls.patch").read_text()
    kvs_added = "\n".join(
        line[1:]
        for line in kvs.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )
    assert 'json:"urls"' in kvs_added
    assert 'json:"url"' not in kvs_added
    assert "DescribeSource" in kvs_added
    assert "go2rtc source state" in kvs_added
    assert "RedactLog" in kvs_added
    assert "X-Amz-Security-Token" not in kvs_added or "TestRedactLog" in kvs_added
    assert hashlib.sha256(kvs.encode()).hexdigest() == (
        "09414081a4e8a020213650ca27b24cf7f0e95061c62b68a28bd4457675b69443"
    )

    repo = yaml.safe_load((ROOT / "repository.yaml").read_text())
    assert repo["name"]
    assert "config.yaml" not in (ROOT / "repository.yaml").read_text()

    forbidden = ("x-access-token", "WMXHYf79", "wyze_app_secret")
    for path in APP.rglob("*"):
        if not path.is_file():
            continue
        text = path.read_text(errors="replace")
        for item in forbidden:
            assert item not in text, f"{item} in {path}"

    run = (APP / "run.sh").read_text()
    assert "set -x" not in run
    assert "FILTER_NAMES" in run
    assert "GWELL_ENABLED=false" in run
    assert "MQTT_ENABLED=false" in run
    assert "BRIDGE_AUTH=true" in run
    assert 'BRIDGE_LISTEN_HOST="172.30.32.1"' in run
    assert "BRIDGE_PORT=5080" in run
    assert "WYZE_RTSP_LISTEN" in run
    assert "192.168.1.70" in run
    assert "empty camera nickname" in run
    assert "127.0.0.1:1984" in run
    assert "0.0.0.0:8554" not in run
    assert "0.0.0.0:1984" not in run
    assert "exec " in run
    print("config ok")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"config check failed: {exc}", file=sys.stderr)
        sys.exit(1)
