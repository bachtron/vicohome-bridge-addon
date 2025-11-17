# Vicohome Bridge Add-on Changelog

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
