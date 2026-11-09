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
    assert config["version"] == "4.5.0-wyzedb3.3"
    assert config["boot"] == "manual"
    assert config["init"] is False
    assert config["host_network"] is False
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
    assert config["ports"] == {"8554/tcp": 8554}
    assert list(config["ports"]) == ["8554/tcp"]
    assert "1984/tcp" not in config["ports"]
    assert "5080/tcp" not in config["ports"]
    assert "8889/tcp" not in config["ports"]
    assert "8189/udp" not in config["ports"]
    assert config["options"] == {"filter_names": "Side door"}
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
    assert schema["filter_names"] == r"match(^[^,\r\n]+$)"
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
    port_key = re.compile(r"^\d+(?:/tcp|/udp)?$")
    for key in config["ports"]:
        assert port_key.match(key), key

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
        "4.5.0+strict-filter",
    ):
        assert needle in dockerfile, needle
    assert "COPY --from=upstream" not in dockerfile
    assert "gwell-proxy" not in dockerfile
    strict = (APP / "patches/strict-filter.patch").read_text()
    assert "return nil" in strict
    assert "refusing to stream the unfiltered list" in strict
    assert "TestFilter_UnmatchedNameIsEmpty" in strict
    assert hashlib.sha256(strict.encode()).hexdigest() == (
        "3f7652f21f9e228ee8cec7506d20b25b6573c089306791fb41f971935d1ac1e3"
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
    assert "exec " in run
    print("config ok")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"config check failed: {exc}", file=sys.stderr)
        sys.exit(1)
