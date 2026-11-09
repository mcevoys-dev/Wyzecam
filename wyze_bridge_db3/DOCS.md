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

## Side door only

`FILTER_NAMES` is the bridge's documented allow-list. The default is `Side door`. Matching is case-insensitive against the camera nickname. The startup script rejects a comma, so the option cannot list a second camera. Set the nickname to the single camera you intend to stream if the Wyze app does not call it exactly `Side door`.

v4.5.0, and tag `v4.6.0-beta.1`, return every camera when that list matches nothing. There is no documented strict option. `patches/strict-filter.patch` changes `Apply` so a configured filter that matches nothing returns no cameras, and changes `Discover` so that case returns `camera filter matched 0 cameras; refusing to stream the unfiltered list`. The bridge then logs the discovery failure and does not register those cameras. This was unit-tested on the patched source. It was not run inside a container and not run against a Wyze account.

MQTT is not enabled. `MQTT_HOST` is cleared. Gwell discovery is off (`GWELL_ENABLED=false`). Recording is off. Periodic snapshots are off. There is no camera-control option in this app.

## Web UI and RTSP

The Web UI listens on container port 5080 and is not published on the host. Ingress is the documented way to open it in a browser: Home Assistant checks the session, and the Supervisor proxies to the app. The bridge also has basic auth (`BRIDGE_AUTH=true`). Ingress is not an RTSP path.

RTSP listens on container port 8554 with `STREAM_AUTH`. The app config maps that container port to host port 8554 by default (`8554/tcp: 8554`). Confirm host port 8554 is free before install. If it is taken, change only that host port on the app's Network page before starting; do not add any other port. This is Supervisor port mapping onto the Home Assistant host, the same kind of LAN RTSP already used for Back Yard. It is not a router or firewall change. RTSP on this port is authenticated and is not wrapped in TLS.

Home Assistant Core runs on the host network, so a mapped host port is how Core reaches the stream: `rtsp://<rtsp_username>:<rtsp_password>@<home-assistant-host>:8554/side_door` when the nickname is `Side door`. Percent-encode a colon inside the password in that URL. The normalized stream name is the nickname in lower case with spaces turned into underscores.

Other apps on `172.30.32.0/23` can still use `{repository}-wyze-bridge-db3:8554`. The repository id is the first 8 hex characters of the SHA-1 of the lowercased Git URL. Clearing the host port in the app Network page unpublishes it again; Core then has no documented path to the stream.

The RTSP username must be at least 8 characters and must not contain `:`, `@`, or `|`. The RTSP password must be at least 16 characters and must not contain `@` or `|`. Both are required, have no defaults, and the app exits before starting the bridge if they are missing or shorter. The schema uses `str(8,)` and `password(16,)`, and `run.sh` checks the same limits.

go2rtc's API on container port 1984 is not in `ports` and `host_network` is false, so that API is not mapped onto the host. Another app on the internal network can still open it, because v4.5.0 cannot set a username on it. `/api/health` and `/metrics.prom` are unauthenticated at the bridge and are also unmapped. The Web UI stays on ingress plus `BRIDGE_AUTH`. Ingress is not RTSP.

This app does not use host networking, `hassio_api`, `homeassistant_api`, the Docker socket, or the Home Assistant configuration folder. Wyze session files are written to `/data/wyze-bridge-state`. A backup of the app includes that directory and the options. Uninstalling the app deletes `/data`.

Logs are fixed at `info`. Trace logging in the bridge can include HTTP bodies, so this app does not offer a log-level option.

## Known limits

No Wyze account, no camera, and no Home Assistant were available. The filter and go2rtc tests ran on source. The container image was not built.

- The upstream README says TUTK doorbells can fail inside Docker NAT, with ICMP "port unreachable" on the camera's UDP reply, and it tells operators to use host networking. Mapping host port 8554 does not change that. This app leaves host networking off. Whether the doorbell actually streams still has to be tested on the real camera. v4.5.0 would expose the unauthenticated go2rtc API on every host interface if host networking were turned on.
- The smaller upstream alternative, not taken here, is pre-release `v4.6.0-beta.1` (`3354db51a028ef636790d7404d7b065f09406092`). It adds `GO2RTC_API_USERNAME` and `GO2RTC_API_PASSWORD`, so a later host-network choice could require a password on port 1984. That tag still fail-opens an unmatched nickname, so it does not replace `strict-filter.patch`. Switching to it would be a new bridge revision, not a one-line change, and host networking would still publish RTSP and WebRTC on the host. This package does not do that.
- The pull request's note says this doorbell's audio is PCML at 8 kHz and the sensor is mounted sideways. This package does not add a rotate step.
- v4.5.0 can promote a TUTK camera to WebRTC after repeated failures (`TUTK_FALLBACK_THRESHOLD`, default 5). That behavior is unchanged.
- linux/amd64 is the only architecture in `arch`. An arm64 go2rtc binary was cross-compiled once and not run.
- The go2rtc patch is unreleased. Nothing here shows that a doorbell streamed.

## Remove it

Stop the app. Then uninstall it from Settings, Apps, this app. Uninstall deletes the app's private data, including the Wyze session files and the saved options. Take a Home Assistant backup first only if you need that data; the backup contains those secrets.

To drop the repository as well, remove its URL from Settings, Apps, Install app, the repositories menu. That is the same screen used to add a Git URL. Removing the repository does not by itself wipe an already installed app's data; uninstall the app for that.

Installing an older copy means pointing that Git URL at a commit you still have, then installing again after the uninstall. Supervisor tracks a branch, or a URL ending in `#branch`. It does not take a commit hash in the URL.
