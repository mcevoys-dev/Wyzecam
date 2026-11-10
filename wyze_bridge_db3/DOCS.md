# Wyze Bridge DB3

This Home Assistant app builds [docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge) v4.5.0 from commit `da56b956b9bfb8f426f8c2efda71f8f2851e76b8` with `patches/strict-filter.patch`, and builds go2rtc v1.9.14 plus the unreleased Wyze Video Doorbell v1 (`WYZEDB3`) change from [go2rtc pull request 2643](https://github.com/AlexxIT/go2rtc/pull/2643), commit `a42e34e431e17e37e82e3bd988db43056e8b8d57`.

The pull request was still open when this package was built. It is not a go2rtc release. v4.5.0 has no strict-filter setting, so the bridge source is patched. The bridge stays AGPL-3.0-only. go2rtc stays MIT. Those notices are in the image under `/usr/local/share/licenses/`. Pins are in `PROVENANCE.md`.

## Before you start it

The app is `boot: manual`. Installing it does not start it, and a restart of Home Assistant does not start it until you turn on "Start on boot" yourself.

The Configuration form has no default account, API key, web password, or RTSP password. Leave it unfilled and the app has nothing to log in with. If it is started anyway, `run.sh` exits before it executes the bridge.

Fill these in on the Configuration tab. The names are the bridge's environment variables.

| Option | Bridge variable | Required |
| --- | --- | --- |
| Wyze account email | `WYZE_EMAIL` | yes |
| Wyze account password | `WYZE_PASSWORD` | yes |
| Wyze API ID | `WYZE_API_ID` | yes |
| Wyze API key | `WYZE_API_KEY` | yes |
| Wyze TOTP key | `WYZE_TOTP_KEY` | only if that Wyze account uses TOTP |
| Web UI username | `BRIDGE_USERNAME` | yes |
| Web UI password | `BRIDGE_PASSWORD` | yes |
| RTSP username | username half of `STREAM_AUTH` | yes |
| RTSP password | password half of `STREAM_AUTH` | yes |
| Camera nickname | `FILTER_NAMES` | yes, default `Side door` |

Home Assistant accepts a `!secret` reference in these fields. The Supervisor resolves it and passes the value in `/data/options.json`. Do not put the values in this package, in a Git commit, or in a screenshot of the log.

`WYZE_API_ID` and `WYZE_API_KEY` are the developer-console values the bridge's own README requires. This package does not include any.

The RTSP username cannot contain `:`, `@`, or `|`. The RTSP password cannot contain `@` or `|`. A colon inside the RTSP password is fine. The bridge parses `STREAM_AUTH` as `username:password`.

## Exact camera names

`FILTER_NAMES` is the bridge's documented allow-list. The default is `Side door,Garage Rear`. Matching is case-insensitive and exact against each camera nickname. A comma separates names. An empty piece, such as a trailing comma, is rejected before the bridge starts. A name that matches nothing is omitted. If the whole list matches nothing, discovery returns `camera filter matched 0 cameras; refusing to stream the unfiltered list` and no camera is registered.

`Garage Rear` is the Wyze Cam Floodlight Pro, model `LD_CFP`. That model is a WebRTC streamer in docker-wyze-bridge v4.5.0. The bridge registers it as `webrtc:http://127.0.0.1:5080/internal/wyze/webrtc/<name>#format=wyze`. go2rtc then fetches a short-lived KVS signaling URL from the loopback shim and dials Wyze's cloud. `Side door` stays on the TUTK path. An existing install keeps its saved option until that option is changed to the two-name list.

v4.5.0, and tag `v4.6.0-beta.1`, return every camera when that list matches nothing. There is no documented strict option. `patches/strict-filter.patch` changes `Apply` so a configured filter that matches nothing returns no cameras, and changes `Discover` so that case returns `camera filter matched 0 cameras; refusing to stream the unfiltered list`. The bridge then logs the discovery failure and does not register those cameras. This was unit-tested on the patched source. It was not run inside a container and not run against a Wyze account.

MQTT is not enabled. `MQTT_HOST` is cleared. Gwell discovery is off (`GWELL_ENABLED=false`). Recording is off. Periodic snapshots are off. There is no camera-control option in this app.

## Web UI and RTSP

Version `4.5.0-wyzedb3.6` sets `host_network: true`. Supervisor then ignores any `ports:` map, so `patches/host-listeners.patch` and `run.sh` choose every listen address.

`run.sh` requires `172.30.32.1` on the host before it starts the bridge. That address is the Supervisor docker-network gateway (`172.30.32.0/23`, host index 1). Ingress connects to it. The Web UI listens on `172.30.32.1:5080`, with `BRIDGE_AUTH=true`. A second listener on `127.0.0.1:5080` serves only `/internal/`. go2rtc's WebRTC client calls `http://127.0.0.1:5080/internal/wyze/webrtc/<camera>` for an `LD_CFP` stream. `requireLoopback` still wraps those handlers, and the ingress listener does not treat a hassio-network client as loopback. The response can carry short-lived TURN credentials. It is not served on the LAN address.

RTSP listens on `192.168.1.70:8554` with `STREAM_AUTH`. Startup checks that this address is present on the host and does not substitute another interface. Core opens `rtsp://<rtsp_username>:<rtsp_password>@192.168.1.70:8554/side_door` and `rtsp://<rtsp_username>:<rtsp_password>@192.168.1.70:8554/garage_rear`. Percent-encode a colon inside the password in that URL. The normalized stream name is the nickname in lower case with spaces turned into underscores.

go2rtc does not ask for RTSP credentials when the client address is `127.0.0.1`. This build therefore refuses to bind RTSP on loopback, on `0.0.0.0`, on link-local, or on `172.30.32.0/23`. `127.0.0.1:8554` has no listener. Home Assistant Core's own go2rtc already uses `127.0.0.1:18554` for RTSP, TCP `18555` for WebRTC, and port `11984` for its API. This app uses none of those.

`192.168.1.70:8554` must be free before the new process binds it. A leftover publish of `0.0.0.0:8554` from an older app can still occupy the port.

The RTSP username must be at least 8 characters and must not contain `:`, `@`, or `|`. The RTSP password must be at least 16 characters and must not contain `@` or `|`. Both are required, have no defaults, and the app exits before starting the bridge if they are missing or shorter. The schema uses `str(8,)` and `password(16,)`, and `run.sh` checks the same limits.

go2rtc's API listens on `127.0.0.1:1984` and has no username in v4.5.0. The loaded modules are `api`, `ws`, `rtsp`, `webrtc`, `wyze`, `ffmpeg`, `exec`, `http`, `mp4`, `hls`, and `mjpeg`. The `hass` module is left out because, for exactly `127.0.0.1:1984`, it would also serve that API on the hassio gateway. The `webrtc` module is the client source (`webrtc:…#format=wyze`). Its `listen` value is empty. go2rtc v1.9.14 opens the TCP and UDP server mux only when that address is non-empty, so `:8555` and `:8889` are not bound. SRTP and RTMP stay unloaded, and their listen values are empty, so `:8443` is not bound. The KVS client still opens ephemeral UDP sockets toward AWS. Those are not stable published ports. Another process in this host network namespace can still open `127.0.0.1:1984` and `127.0.0.1:5080`. An app that stays on the hassio bridge cannot. The Web UI stays on ingress plus `BRIDGE_AUTH`.

TUTK still opens ephemeral UDP sockets so the doorbell can answer discovery. Those sockets are the reason for host networking. They are not fixed published ports.

This app does not use `hassio_api`, `homeassistant_api`, the Docker socket, or the Home Assistant configuration folder. Wyze session files are written to `/data/wyze-bridge-state`. A backup of the app includes that directory and the options. Uninstalling the app deletes `/data`.

Logs are fixed at `info`. Trace logging in the bridge can include HTTP bodies, so this app does not offer a log-level option.

## Known limits

No Wyze account, no camera, and no Home Assistant were available. The filter and go2rtc tests ran on source. The container image was not built.

- `4.5.0-wyzedb3.5` registered `Garage Rear` as streaming and then delivered no media. The shim labeled ICE servers `url`. go2rtc v1.9.14 reads `urls` and otherwise builds peer connections with no STUN or TURN servers, so a KVS camera cannot complete ICE. `4.5.0-wyzedb3.6` sends `urls`. A failed dial is logged as `go2rtc source state` with the error text after URL queries are removed.
- `LD_CFP` media and signaling still go through Wyze's AWS KVS service. The doorbell remains on TUTK. This source change was not run against a camera.
- The KVS shim returns short-lived TURN credentials. It is bound to `127.0.0.1:5080` and still checks the peer address.
- v4.5.0 cannot set a password on the go2rtc API. The API is bound to `127.0.0.1:1984` so the LAN does not see it. Any other host-network process on this machine can.
- The upstream alternative with `GO2RTC_API_USERNAME` is pre-release `v4.6.0-beta.1` (`3354db51a028ef636790d7404d7b065f09406092`). That tag still fail-opens an unmatched nickname, so it does not replace `strict-filter.patch`. This package stays on v4.5.0 plus the two local patches.
- The pull request's note says this doorbell's audio is PCML at 8 kHz and the sensor is mounted sideways. This package does not add a rotate step.
- v4.5.0 can promote a TUTK camera to WebRTC after repeated failures (`TUTK_FALLBACK_THRESHOLD`, default 5). That behavior is unchanged.
- linux/amd64 is the only architecture in `arch`. An arm64 go2rtc binary was cross-compiled once and not run.
- The go2rtc patch is unreleased. Nothing here shows that a doorbell streamed.

## Remove it

Stop the app. Then uninstall it from Settings, Apps, this app. Uninstall deletes the app's private data, including the Wyze session files and the saved options. Take a Home Assistant backup first only if you need that data; the backup contains those secrets.

To drop the repository as well, remove its URL from Settings, Apps, Install app, the repositories menu. That is the same screen used to add a Git URL. Removing the repository does not by itself wipe an already installed app's data; uninstall the app for that.

Installing an older copy means pointing that Git URL at a commit you still have, then installing again after the uninstall. Supervisor tracks a branch, or a URL ending in `#branch`. It does not take a commit hash in the URL.
