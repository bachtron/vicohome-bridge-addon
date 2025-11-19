# Vicohome Bridge Add-on Changelog

## 1.5.5
- Ensured every `grep -E` check in `maybe_warn_region_mismatch()` passes `--` before patterns like `-1001`, so BusyBox no longer
  mistakes the pattern for CLI flags and spams "grep: unrecognized option: 1" during event polling.

## 1.5.4
- Hardened the region-mismatch detector in `run.sh` by making every `grep` invocation BusyBox-compatible (explicit `--` before the
  `-1001` pattern), eliminating the "grep: unrecognized option: 1" errors that appeared after event polling when Vicohome
  returned those error codes.

## 1.5.3
- Replaced the ad-hoc "No events found" check in `run.sh` with a helper that uses BusyBox-safe `grep -F -q` semantics so event
  polling never invokes unsupported `grep -1` flags and the add-on stops logging "grep: unrecognized option: 1" after every
  empty window.
- Updated the vendored `vico-cli` installer script to request the latest release tag with `grep -m 1`, ensuring BusyBox systems
  only rely on options that are actually implemented.

## 1.5.2
- Make `vico-cli` derive the correct `countryNo` from the configured API base even when the add-on's default `region` value is
  still set to `us`, so EU installations that only override `api_base` also receive telemetry/metadata instead of "unknown"
  devices.

## 1.5.1
- Fixed the `vico-cli devices` and event helpers to send a region-aware `countryNo`, so EU deployments now receive the same
  camera metadata/telemetry as US users instead of "unknown" devices.

## 1.5.0
- Added an optional go2rtc bridge: every WebRTC ticket can now be mirrored to `http://go2rtc:1984/api/stream` using the `vicohome_<safe_id>` naming convention, making it easier for the go2rtc add-on to ingest Vicohome tickets without its own MQTT subscriber.
- Introduced the `go2rtc_enabled`, `go2rtc_url`, and `go2rtc_stream_prefix` configuration options (disabled by default) so users can turn on the HTTP bridge only when a go2rtc instance is available.
- Documented the HTTP payload structure and workflow in the README alongside the existing MQTT-based instructions.

## 1.4.0
- Added experimental WebRTC / P2P ticket export so power users can request Vicohome tickets over MQTT and hand them to go2rtc (or other tooling) without modifying the add-on image.
- Introduced `webrtc_enabled`, `webrtc_mode`, and `webrtc_poll_interval` configuration options plus matching MQTT request/ticket/status topics while keeping the feature opt-in by default.
- Documented the go2rtc tie-in pattern and WebRTC topic schema in the README so integrators have a consistent naming convention (`vicohome_<safe_id>` streams).

## 1.3.0
- Added regional awareness to `vico-cli` so the bridge can authenticate and poll either the US or EU Vicohome shards (or any
  fully-qualified custom API host) based on the new configuration options.
- Introduced `region` / `api_base` add-on options and exported them as `VICOHOME_REGION` / `VICOHOME_API_BASE` environment
  variables so the integration defaults to the US cloud but can be pointed at EU or white-label deployments without custom
  images.

## 1.2.2
- Extended the bootstrap history pull to cover the last 5 days of Vicohome activity so Last Event sensors populate even when your account has been idle for more than a day.

## 1.2.1
- Reworked the bootstrap history fallback to use an in-memory flag and replay the last 24 hours of Vicohome events whenever `vico-cli` reports no recent motion, ensuring the normal MQTT workflows run even during the bootstrap phase.

## 1.2.0
- Added an optional bootstrap history pull that backfills the most recent event per camera when Vicohome reports no recent activi
ty, so the Last Event sensors populate even before new motion occurs.
- Provided a `bootstrap_history` configuration toggle (default `true`) and persisted per-camera markers so the historical publish
ing only runs once per install unless you disable/delete the data files.

## 1.1.9
- Added an automatic MQTT discovery refresh (every ~5 minutes) so Home Assistant recreates Vicohome entities if you delete them or when payloads change over time.
- Logged the discovery refresh reason to the add-on log for easier troubleshooting when sensors appear to lag behind changes.

## 1.1.8
- Fixed a regression where the telemetry publisher could crash with an `online_json` error when Vicohome omitted status flags, ensuring the add-on keeps running even with sparse device data.
- Added detailed debug logging for telemetry and events (and documented how to enable it) so troubleshooting stalled updates is much easier.

## 1.1.7
- Added a retained MQTT availability topic and wired every discovery payload to it so Home Assistant marks the entities unavailable whenever the add-on goes offline.

## 1.1.6
- Fixed the Last Event sensor discovery template so it also recognizes `event_type` payloads, ensuring Home Assistant always shows the motion type regardless of the JSON casing Vicohome uses.

## 1.1.5
- Improved the telemetry publisher so it recognizes more battery and Wi-Fi signal fields from Vicohome payloads and always forwards that data to Home Assistant.
- Added missing trailing newlines to repository metadata and the main run script to avoid formatting diffs when packaging the add-on.

## 1.1.4
- Fixed a bash runtime error when telemetry payloads arrived without an explicit `online` field by ensuring the fallback logic
  always initializes the variable before use.

## 1.1.3
- Added explicit changelog metadata so Home Assistant shows release notes in the add-on store.
- Documented the telemetry and MQTT discovery improvements introduced in this release.
- Fixed repository metadata to point to the real project home.

## 1.1.2
- Initial release of the add-on.
