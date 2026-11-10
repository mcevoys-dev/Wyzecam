# Wyze Bridge DB3

Home Assistant app that builds [docker-wyze-bridge](https://github.com/IDisposable/docker-wyze-bridge) v4.5.0 (`da56b956b9bfb8f426f8c2efda71f8f2851e76b8`) with a strict camera filter, and go2rtc v1.9.14 plus the unreleased Wyze Video Doorbell v1 patch ([go2rtc#2643](https://github.com/AlexxIT/go2rtc/pull/2643), `a42e34e431e17e37e82e3bd988db43056e8b8d57`).

The doorbell change is not in a go2rtc release. An unmatched nickname list does not fall open to every camera. The app starts stopped. Version 4.5.0-wyzedb3.7 uses the host network and can list `Side door,Garage Rear`. Authenticated RTSP listens on 192.168.1.70:8554. The Web UI listens on 172.30.32.1:5080 for ingress, with basic auth. The KVS shim listens on 127.0.0.1:5080. The go2rtc API listens on 127.0.0.1:1984. The WebRTC client is enabled and the WebRTC server ports stay closed. Operator steps are in `DOCS.md`. Pins are in `PROVENANCE.md`.

No image of this app is published. Supervisor builds `Dockerfile` on the machine when the app is installed from the public Git repository it can clone: https://github.com/mcevoys-dev/Wyzecam
