# Wyze Bridge DB3

Home Assistant app that builds [docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge) v4.5.0 (`da56b956b9bfb8f426f8c2efda71f8f2851e76b8`) with a strict camera filter, and go2rtc v1.9.14 plus the unreleased Wyze Video Doorbell v1 patch ([go2rtc#2643](https://github.com/AlexxIT/go2rtc/pull/2643), `a42e34e431e17e37e82e3bd988db43056e8b8d57`).

The doorbell change is not in a go2rtc release. An unmatched nickname does not fall open to every camera. The app starts stopped. Authenticated RTSP defaults to host port 8554. The go2rtc API is not mapped and host networking is off. Operator steps are in `DOCS.md`. Pins are in `PROVENANCE.md`.

No image of this app is published. Supervisor builds `Dockerfile` on the machine when the app is installed from the public Git repository it can clone: https://github.com/mcevoys-dev/Wyzecam
