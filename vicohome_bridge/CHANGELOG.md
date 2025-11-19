# Vicohome Bridge Add-on Changelog

## 1.5.10
- Fixed a startup regression introduced while stripping the WebRTC helpers by
  hardening the `vico-cli` invocation wrappers so transient API failures no
  longer abort the add-on during the first telemetry poll.
- Removed the leftover camera metadata cache hooks that only existed for the
  experimental streaming workflow.

## 1.5.9
- Removed the experimental peer-to-peer streaming hooks (MQTT commands,
  ticket mirroring, and HTTP bridge helpers) so the add-on focuses entirely on
  the stable cloud telemetry + event bridge with multi-region support. No
  configuration changes are required other than removing the unused options.

## 1.5.8
- Removed the experimental direct-stream export plumbing and its HTTP mirror from
  the add-on scripts/configuration so the focus returns to the core MQTT
  discovery, telemetry, and multi-region event polling features.
- Updated the README to reflect the current installation/operation flow.

## 1.5.7
- Hardened the region mismatch detector by using POSIX character classes in the
  BusyBox-compatible `grep` checks, ensuring the add-on can safely detect `-1001`
  errors without tripping over unsupported numeric options.
- Documented the rebuild process in the README so users running from a git
  checkout know they must reinstall/rebuild the add-on after pulling new
  commits to pick up fixes like the `grep` compatibility patches.

## 1.5.6
- Updated the Last Event MQTT discovery template to use `value_json.get(...)` lookups so Home Assistant no longer logs template
  warnings when Vicohome payloads omit `eventType`/`type` fields, while still falling back to `unknown` when no type is present.

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
