# Wyze Bridge DB3

A Home Assistant app package for one Wyze camera. It builds [IDisposable/docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge) v4.5.0 from commit `da56b956b9bfb8f426f8c2efda71f8f2851e76b8` plus `wyze_bridge_db3/patches/strict-filter.patch`, and go2rtc v1.9.14 plus the unreleased Wyze Video Doorbell v1 (`WYZEDB3`) fix from [AlexxIT/go2rtc pull request 2643](https://github.com/AlexxIT/go2rtc/pull/2643), commit `a42e34e431e17e37e82e3bd988db43056e8b8d57`.

That pull request was open, not merged. v4.5.0 has no strict camera filter, so the bridge source is patched: an unmatched nickname yields no cameras and a discovery error, not the rest of the account. Pins and licenses are in `wyze_bridge_db3/PROVENANCE.md`. Options and limits are in `wyze_bridge_db3/DOCS.md`.

## What is in the box

```text
repository.yaml
wyze_bridge_db3/
  config.yaml
  Dockerfile
  run.sh
  DOCS.md
  PROVENANCE.md
  translations/en.yaml
  patches/strict-filter.patch
  patches/host-listeners.patch
  patches/wyzedb3-a42e34e-pkg-tutk.patch
  patches/UPSTREAM-a42e34e.diff
  LICENSES/
```

`config.yaml` is `boot: manual`, `arch: [amd64]`, `host_network: true`, and ingress on port 5080. The only default option is `filter_names: Side door`. Account, API, web, and RTSP values have no defaults. `run.sh` exits if any required value is empty, and it does not print those values. With host networking, Supervisor ignores `ports:`. `patches/host-listeners.patch` chooses the sockets instead.

There is no `image:` key. Nothing is pushed to a registry. After a repository is added, Supervisor builds the Dockerfile on the Home Assistant machine.

## Install

Supervisor installs this app from a Git URL it can clone with no login. Add this repository:

`https://github.com/mcevoys-dev/Wyzecam`

The documented step is Settings → Apps → Install app → Repositories, then that public HTTPS URL. A `#branch` suffix selects a branch. `POST /store/repositories` takes the same URL and no separate credential.

Token-in-URL is not in the repository guide, and [Supervisor issue 7453](https://github.com/home-assistant/supervisor/issues/7453) reports that form failing. File editor, SSH, and Samba are not the install path: Enforce Basepath keeps the editor in the Home Assistant configuration directory, and `local_apps` is a different directory.

After that URL is added, install **Wyze Bridge DB3**, fill the Configuration tab, and only then press Start. The app stays off through install and through a reboot until you start it. The Dockerfile compiles linux/amd64 on the device. No prebuilt app image is published.

## Options the bridge receives

| App option | Exported as |
| --- | --- |
| `wyze_email` | `WYZE_EMAIL` |
| `wyze_password` | `WYZE_PASSWORD` |
| `wyze_api_id` | `WYZE_API_ID` |
| `wyze_api_key` | `WYZE_API_KEY` |
| `wyze_totp_key` | `WYZE_TOTP_KEY` when set |
| `web_username` | `BRIDGE_USERNAME`, with `BRIDGE_AUTH=true` |
| `web_password` | `BRIDGE_PASSWORD` |
| `rtsp_username`, `rtsp_password` | `STREAM_AUTH=username:password` (at least 8 and 16 characters; no defaults) |
| `filter_names` | `FILTER_NAMES` (comma-separated exact nicknames, default `Side door,Garage Rear`) |

Also forced: `GWELL_ENABLED=false`, `MQTT_ENABLED=false`, `MQTT_HOST` unset, `LOG_LEVEL=info`, `RECORD_ALL=false`, `SNAPSHOT_INTERVAL=0`. Session files go to `/data/wyze-bridge-state`.

## Rebuild the amd64 go2rtc binary

The app image builds this itself. To rebuild the same binary on a workstation that has curl, patch, and Go 1.24.11:

```bash
./scripts/build-go2rtc-linux-amd64.sh
```

The script checks the upstream tarball sha256, applies `wyze_bridge_db3/patches/wyzedb3-a42e34e-pkg-tutk.patch`, runs `go test ./pkg/tutk/ ./pkg/tutk/dtls/`, and writes `dist/go2rtc-linux-amd64` plus `dist/SHA256SUMS`. The script's Go build flags match the Dockerfile: `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -buildvcs=false -ldflags '-s -w'`.

Check the app files and the strict filter without a camera:

```bash
python3 tests/test_config.py
bash tests/test_run.sh
./scripts/test-strict-filter.sh
```

`test-strict-filter.sh` needs Go 1.26.4, the same compiler image major as the Dockerfile. It checks the v4.5.0 tarball, applies `strict-filter.patch`, and runs `TestFilter_`.

## Rollback

1. Stop the app.
2. Uninstall it under Settings, Apps. Uninstall deletes `/data` for the app, including the Wyze session directory and the saved options. Take a Home Assistant backup first only when you need that data. The backup contains those secrets.
3. Remove the Git URL from the repositories menu if you do not want the store entry. The menu is Settings, Apps, Install app, Repositories. See [Installing and managing apps](https://www.home-assistant.io/common-tasks/os/apps/).
4. To install an older tree, point the repository URL at a branch that still has it (`https://example/repo.git#branch`), check for updates, and install again. Supervisor does not accept a commit hash in the URL.

## Limits, stated separately from any camera test

No Wyze login, no camera, and no Home Assistant were available. Unit tests cover the strict filter and the go2rtc packet and DTLS changes. They do not show that a doorbell streamed. The app container was not built; this environment has no Docker daemon.

Version `4.5.0-wyzedb3.5` keeps host networking and adds a second exact nickname for the Floodlight Pro (`LD_CFP`, `Garage Rear`). That model uses Wyze's cloud KVS WebRTC path. The go2rtc WebRTC module is loaded as a client only. Its listen address stays empty, so ports 8555, 8889, and 8443 are not opened. The client dials AWS using ephemeral UDP. That is the accepted cloud dependency.

Listeners on the host stack:

| Socket | Address | Who can open it |
| --- | --- | --- |
| Web UI | `172.30.32.1:5080` | Supervisor ingress. Basic auth stays on. |
| Internal shim | `127.0.0.1:5080` | `/internal/` only. go2rtc's `webrtc:` client fetches the KVS signaling URL here. |
| go2rtc API | `127.0.0.1:1984` | This host only. The hass module is not loaded. |
| RTSP | `192.168.1.70:8554` | LAN clients of that address, with `STREAM_AUTH`. |
| WebRTC, SRTP, RTMP servers | disabled | No listener on 8555, 8889, or 8443. |

Home Assistant Core's go2rtc already listens on `127.0.0.1:18554`, TCP `18555`, and port `11984`. This app does not use those ports. go2rtc skips RTSP auth for a connection from `127.0.0.1`, so RTSP is not bound there. Use `rtsp://<rtsp_username>:<rtsp_password>@192.168.1.70:8554/side_door` and `.../garage_rear`. A real camera test is still required.

An unmatched nickname is a discovery error and zero cameras. That is covered by `scripts/test-strict-filter.sh` on the patched source, not by a container run.

aarch64 was not run. A cross-compile of go2rtc for `linux/arm64` succeeded once and was not executed and is not packaged. The app `arch` list is amd64 only.
