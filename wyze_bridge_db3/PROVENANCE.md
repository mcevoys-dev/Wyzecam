# Provenance

The go2rtc change is not in a go2rtc release. Pull request 2643 was open
on 9 November 2026, with a single commit.

The bridge is docker-wyze-bridge v4.5.0 source plus one local patch,
`patches/strict-filter.patch`. v4.5.0 has no documented strict-filter
option. `FILTER_NAMES` is an allow-list, and `Apply` returned every
camera when the allow-list matched nothing (`never filter to empty`).
The same return is still in tag `v4.6.0-beta.1`. This package therefore
builds the bridge from the v4.5.0 commit instead of copying the
published image binary. The patch makes an unmatched filter return no
cameras, and `Discover` returns an error instead of continuing with the
full list. The bridge remains AGPL-3.0-only. The corresponding source
is that commit plus this patch.

## docker-wyze-bridge

| Item | Value |
| --- | --- |
| Project | https://github.com/IDisposable/docker-wyze-bridge |
| Tag | `v4.5.0` |
| Commit | `da56b956b9bfb8f426f8c2efda71f8f2851e76b8` |
| License | AGPL-3.0-only. Text is in `LICENSES/docker-wyze-bridge-AGPL-3.0.txt`. |
| Image | `idisposablegithub365/wyze-bridge` |
| Tag digest (manifest list) | `sha256:708903d2882c76966ecb29763a075372d89773aa6796d0aab70f04369cc6d521` |
| linux/amd64 manifest | `sha256:02f21ef39c1c3bd70e7123b2503e3543bb8d2d703ecfd4de83288e29b7f45483` |
| Image config | `sha256:3a17f054e39799e4e237b9ed97829d0f76eae34cbc2475ed5e1da34701c582ea` |
| Image created | `2026-07-02T22:14:35Z` |
| `org.opencontainers.image.revision` | `da56b956b9bfb8f426f8c2efda71f8f2851e76b8` |
| `org.opencontainers.image.version` | `4.5.0` |
| Bundled go2rtc in that image's Dockerfile | release binary `v1.9.14` (`ARG GO2RTC_VERSION=1.9.14`) |
| Source tarball sha256 | `318b8f1e41c2ffe994b326fbfac0ccbb84718ee24ee0ea76f3fe5943d693d2db` |
| Strict-filter patch sha256 | `3f7652f21f9e228ee8cec7506d20b25b6573c089306791fb41f971935d1ac1e3` |
| Compiler image | `golang:1.26.4-alpine` linux/amd64 `sha256:0648ddfa35769070197ba1cdf22a16dc452caf9315e66b91791308a543baf229` |
| Bridge binary version string | `4.5.0+strict-filter` |
| linux/amd64 bridge binary built here | `b683ef50ef8bf3c7ca32d701ea011eae2afc316823143ac3c32efe8115701cb0` |

The published image is the unmodified v4.5.0 build of this commit. This
Dockerfile does not copy that binary, because the fail-open filter is
inside it. `gwell-proxy` is not built. The app sets `GWELL_ENABLED=false`.

The bridge binary hash above is from `go build` on this workstation with
Go 1.26.4. The Supervisor image build compiles it again, so that hash is
not an image-layer hash. No container image was built here.

## go2rtc

| Item | Value |
| --- | --- |
| Project | https://github.com/AlexxIT/go2rtc |
| Release used as the base | `v1.9.14` |
| Release commit | `b5948cfb25404cc5cb37b166ecaa2dca20b11d4b` |
| Release tarball | https://github.com/AlexxIT/go2rtc/archive/b5948cfb25404cc5cb37b166ecaa2dca20b11d4b.tar.gz |
| Tarball sha256 | `78aa79bcedec8f155e4060a379613979b0b3ee48ff62ee5164bafc0ac6532386` |
| License | MIT. Copyright (c) 2022 Alexey Khit. Text is in `LICENSES/go2rtc-MIT.txt`. |
| Module Go version | `go 1.24.0` |
| Compiler image | `golang:1.24.11-alpine` |
| Compiler image digest (linux/amd64) | `sha256:1a97fbadb2eb46ba8e4bce6b08f45bc24ef0180d1f3b3192886a080c8268ba71` |
| Compiler index digest | `sha256:ef75fa8822a4c0fb53a390548b3dc1c39639339ec3373c58f5441117e1ff46ae` |

## Unreleased WYZEDB3 patch

| Item | Value |
| --- | --- |
| Pull request | https://github.com/AlexxIT/go2rtc/pull/2643 |
| State checked | open, updated 2026-11-03, not merged |
| Commit | `a42e34e431e17e37e82e3bd988db43056e8b8d57` |
| Parent | `7c05066c90ab6ad1fccb506d5f0408aa31ebe60f` (`v1.9.15`) |
| Author | Brody Golden |
| Commit date | 2026-11-03 |
| Exact commit diff | `patches/UPSTREAM-a42e34e.diff` (5 files, sha256 `3fc17f54dd4e526631fd3a39bdb9d202348d825259f81465d0f325cc2710de28`) |
| Diff applied to v1.9.14 | `patches/wyzedb3-a42e34e-pkg-tutk.patch` (sha256 `219f39231ca00a148c2b6f97f644812814adb9c6c718f3487435f61c5387fb91`) |

`pkg/tutk/frame.go` and `pkg/tutk/dtls/dtls.go` are identical between
`v1.9.14` and the patch parent `v1.9.15`. The `pkg/tutk` hunks therefore
apply to the release the bridge ships. The commit also edits
`internal/wyze/README.md`. That hunk does not apply to the v1.9.14 copy
of the file, and it does not change the binary. The image build does not
apply it.

The patch parent is v1.9.15 (`go 1.26.0`), which also changes
`pkg/tutk/session16.go` and `pkg/tutk/session25.go`. Those session changes
are not part of this package. The bridge author of the pull request said
the live doorbell test used docker-wyze-bridge 4.5.0 with go2rtc 1.9.14
plus this fix. That is the combination built here.

Reported version string inside the rebuilt binary:
`1.9.14+wyzedb3.a42e34e`.

linux/amd64 binary produced by `scripts/build-go2rtc-linux-amd64.sh`
with Go 1.24.11 on 9 November 2026:

`5f837500884bb88f705bb1b313925ab48dec4d50a86986548665d116edf023bc`

That file is not committed. It is in the downloadable archive under
`dist/`. The app image compiles go2rtc again during the Supervisor
build, so the image layer hash is not this file's hash.

## Home Assistant base

| Item | Value |
| --- | --- |
| Image | `ghcr.io/home-assistant/base:3.24` |
| Index digest | `sha256:58422480a299b16b6ea376c2167463206d430619ed02b40cd687c8bd6875519e` |
| linux/amd64 manifest used by this Dockerfile | `sha256:ed340acf0a3a77a761b4d3ee2977ab5ddc44038304597e66b0ccfd859b8d8a1f` |

`build.yaml` is not used. Home Assistant documents it as deprecated.
Supervisor 2026.04.0 and later does not pass `BUILD_FROM` unless that
file is present. The base image is the `FROM` line in the Dockerfile.

## What was checked on 9 November 2026

go2rtc, with Go 1.24.11 on linux/amd64:

- `pkg/tutk/frame.go` and `pkg/tutk/dtls/dtls.go` match between v1.9.14 and v1.9.15.
- The `pkg/tutk` patch applies to the v1.9.14 tarball with `patch -p1`.
- `go test ./pkg/tutk/ ./pkg/tutk/dtls/` passed on the patched tree.
- The same new DTLS test, copied onto unmodified v1.9.14, failed in `TestClientHandshakeAESOnlyServer` (`InsufficientSecurity`). The patched tree passes that test and `TestClientHandshakeChaChaServer`.
- `CGO_ENABLED=0 GOOS=linux GOARCH=amd64` produced a static amd64 go2rtc binary. Its sha256 is recorded in the go2rtc section.
- `GOARCH=arm64` also compiled a static go2rtc binary from the patched git tree. That binary was not executed, and this app does not ship it.

Bridge filter, with Go 1.26.4 on linux/amd64, after `strict-filter.patch` on the v4.5.0 tarball:

- `TestFilter_UnmatchedNameIsEmpty` passed: nickname `SIDE DOOR` against other cameras returned 0.
- `TestFilter_MatchedNameOnly` passed: `Side door` was the only camera returned.
- The other `TestFilter_*` cases still passed, including an empty filter returning every camera.
- `go build` produced a static amd64 `wyze-bridge` binary with version string `4.5.0+strict-filter`.

`tests/test_run.sh` checked startup with a fake bridge. It does not exercise the filter; that is the Go test above.

## Host listeners and LD_CFP, v4.5.0-wyzedb3.5

`patches/strict-filter.patch` sha256 `32ab5196f1d6205c12f2d93e9a326f58012635e7feec19eab88ee312bdac97d4` keeps an unmatched name list empty and adds `TestFilter_TwoExactNames` and `TestFilter_PartialNameIsEmpty`.

`patches/host-listeners.patch` sha256 `6b89affb61b8a33b522a6df70e08e5b7b68c2c64bd5ea3ffe7a3f0d247b2ade5` is applied to the same v4.5.0 tree after the strict filter. It changes three files: `internal/config/config.go`, `internal/go2rtcmgr/config.go`, and `internal/webui/server.go`.

| Listener | Resulting address | Why |
| --- | --- | --- |
| go2rtc API | `127.0.0.1:1984` | The bridge client is hardcoded to that URL. The `hass` module is not loaded, so go2rtc does not also bind the hassio gateway. |
| Web UI | `172.30.32.1:5080` | Supervisor ingress uses the hassio gateway. Any other host is refused. |
| Internal shim | `127.0.0.1:5080` | Only `/internal/` routes. go2rtc's `webrtc:` client calls `/internal/wyze/webrtc/<camera>` on this port. |
| RTSP | `192.168.1.70:8554` | `run.sh` requires this address on the host. Loopback, `0.0.0.0`, link-local, and `172.30.32.0/23` are refused because go2rtc skips RTSP auth for `127.0.0.1`. |
| WebRTC, SRTP, RTMP servers | empty `listen` | The `webrtc` module is loaded so the client source exists. go2rtc opens `:8555` only when `listen` is non-empty. SRTP and RTMP stay unloaded. |

Home Assistant Core, in current `dev` `homeassistant/components/go2rtc/server.py`, uses `127.0.0.1:18554`, `:18555/tcp`, and API port `11984`. This patch does not bind those.

`LD_CFP` is `IsWebRTCStreamer` in docker-wyze-bridge v4.5.0. The stream URL is `webrtc:http://127.0.0.1:5080/internal/wyze/webrtc/<name>#format=wyze`. go2rtc v1.9.14 implements that format in `internal/webrtc/client.go`. The KVS client uses ephemeral UDP toward AWS. Those sockets are not the fixed server ports above.

The patched bridge compiled with Go 1.26.4 and `go test ./internal/camera/ -run TestFilter_` passed. This VM has no Docker daemon, so the Home Assistant image was not built here. Nothing here shows that a doorbell or a floodlight streamed.
