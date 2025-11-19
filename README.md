# Vicohome Bridge Add-on for Home Assistant

Repo: <https://github.com/KIWIDUDE564/vicohome-bridge-addon>

> ⚠️ **Unofficial integration.**  
> This add-on is just a thin wrapper around the excellent open-source
> [`vico-cli`](https://github.com/dydx/vico-cli) project by **dydx**.  
> It is **not** affiliated with Vicohome or the vico-cli author.

The Vicohome Bridge add-on uses `vico-cli` + MQTT to bring your **Vicohome cameras** into Home Assistant.

It:

- Logs into Vicohome with `vico-cli`
- Polls the cloud for **events + device info**
- Publishes JSON events and camera attributes to MQTT
- Uses **MQTT Discovery** to auto-create entities for each camera
- Republishes discovery every few minutes so deleted entities get recreated automatically
- Performs a one-time history bootstrap when Vicohome reports no recent motion so Last Event sensors populate even before new motion (configurable)
- Listens for MQTT commands to fetch official Vicohome P2P/WebRTC tickets so you can hand them to go2rtc or another bridge for live view
- Provides a simple **dashboard** with last-event thumbnails and camera health

Tested on:

- Home Assistant OS (aarch64 / Raspberry Pi)

---

## Strongly recommended account setup

For safety and sanity:

1. Keep your existing Vicohome account as your **main account**.
2. Create a **new “bridge” account** in the Vicohome app (e.g. `homeassistant_bridge@example.com`).
3. From the main account, **share all cameras** to the bridge account.
4. Use **only** the bridge account credentials in this add-on.

This keeps your main login out of Home Assistant and also makes it easy to revoke/remove access later if needed.

---

## Features

For each Vicohome camera the add-on creates:

- `sensor.vicohome_<cam>_last_event`  
  - JSON attributes: `timestamp`, `imageUrl`, `videoUrl`, `eventType`, `serialNumber`, `deviceName`, etc.
- `binary_sensor.vicohome_<cam>_motion`
- `sensor.vicohome_<cam>_battery` (percentage)
- `sensor.vicohome_<cam>_wifi` (signal dBm)
- `binary_sensor.vicohome_<cam>_online`
- Shared availability topic so every entity goes `unavailable` if the add-on stops

Plus:

- Motion pulses (`ON` → short delay → `OFF`) for automations
- Base MQTT topic configurable (default `vicohome`)
- Polling interval configurable (default 60s)

---

## Requirements

- **Home Assistant OS** or **Supervised** (add-on support required)
- **MQTT broker** available to Home Assistant  
  Recommended: the official **Mosquitto broker add-on** (`core-mosquitto`)
- A **Vicohome bridge account**  
  - Created in the Vicohome app
  - Cameras are **shared** to this account from your main Vicohome account

Optional (for the dashboard):

- **HACS** installed
- `config-template-card` installed via HACS  
  (used to render the dynamic markdown dashboard)

---

## Installation

### 1. Add the add-on repository

In Home Assistant:

1. Go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮ menu → Repositories**.
3. Add this repo URL:

   ```text
   https://github.com/KIWIDUDE564/vicohome-bridge-addon
   ```

4. Click **Add**, then **Close**.

You should now see **“Vicohome Bridge”** in the add-on list.

---

### 2. Install the Vicohome Bridge add-on

1. In **Add-on Store**, click **Vicohome Bridge**.
2. Click **Install**.
3. After installation, go to the **Configuration** tab and fill in:

   - `email` – **bridge Vicohome account** email  
     (the one you shared your cameras to, *not* necessarily your main login)
   - `password` – bridge account password
   - `poll_interval` – how often to poll for events (seconds)
   - `base_topic` – MQTT base topic (default: `vicohome`)
   - `log_level` – `debug`, `info`, `warning`, `error` (default: `info`). Use `debug` when you need extra telemetry/event payload details in the add-on logs.
   - `region` / `api_base` – optional Vicohome shard overrides. Leave the defaults (`us` / empty) unless you know you need the EU shard or a custom API hostname.
   - `bootstrap_history` – set to `false` to skip the one-time history pull when Vicohome returns "No events found" (default: `true`).
   - `webrtc_enabled` / `webrtc_mode` / `webrtc_poll_interval` – opt-in controls for the experimental WebRTC ticket export (see below). By default WebRTC support is disabled; enable it only if you plan to consume tickets with go2rtc or another P2P helper.
   - `go2rtc_enabled` / `go2rtc_url` / `go2rtc_stream_prefix` – optional HTTP bridge to a go2rtc instance (default host: `http://go2rtc:1984/api/stream`). When enabled the add-on POSTs every ticket to that endpoint using the naming convention `vicohome_<safe_id>`.

   Example:

   ```json
   {
     "email": "homeassistant_bridge@example.com",
     "password": "YOUR_PASSWORD_HERE",
     "poll_interval": 60,
     "base_topic": "vicohome",
     "log_level": "info",
     "bootstrap_history": true
   }
   ```

4. Click **Save**.
5. On the **Info** tab, enable:
   - **Start on boot**
   - **Watchdog**
6. Click **Start**.

#### Vicohome regions & troubleshooting

- `region` accepts `auto` (default), `us`, or `eu`. `auto` resolves to the US cloud unless you also provide a full `api_base` URL.
- EU accounts should explicitly set `region: eu` so every `vico-cli` command and MQTT payload targets `https://api-eu.vicoo.tech`.
- Custom/white-label deployments can leave `region: auto` and instead point `api_base` to the desired Vicohome host.
- On startup the add-on logs both the configured region and the resolved API host, making it easy to confirm which shard is in use.
- **Troubleshooting:** if the logs ever show `ACCOUNT_NOT_REGISTERED (-1001)`, double-check your bridge account email/password and try changing the `region` option (for example, from `auto` to `eu`). That error almost always means the Vicohome shard/region does not match your account.

---

### 3. Ensure MQTT is configured

The add-on uses Supervisor **service discovery** to find your MQTT broker.

You should have:

1. The **Mosquitto broker** add-on installed and running, **or**
2. Another MQTT broker exposed to Home Assistant as a “MQTT” service.

Then:

1. Go to **Settings → Devices & Services**.
2. Add / configure the **MQTT integration** and point it to your broker.
3. Once MQTT is working, the Vicohome Bridge logs should show something like:

   ```text
   [INFO] Using MQTT broker at core-mosquitto:1883, base topic: vicohome
   ```

No manual host/port config is needed in the add-on; it grabs them from the MQTT service automatically.

### Troubleshooting & verbose logging

If you are chasing down missing events or telemetry, edit the add-on configuration and set `log_level` to `debug`. The bridge will:

- Dump previews of every Vicohome event payload that arrives
- Summarize and log the battery/Wi-Fi/online telemetry pushed to MQTT
- Include counts and raw previews of each `vico-cli devices list` call

These extra details make it easier to see what the Vicohome cloud is returning and why certain entities may not update.

#### Historical bootstrap for Last Event sensors

When `vico-cli` reports `No events found in the specified time period.`, the add-on performs a **one-time history pull** (last ~5 days) and replays those events to MQTT just like live motion. This ensures your Last Event sensors and automations have recent context even before fresh motion occurs. Disable `bootstrap_history` if you prefer to wait for brand new events instead of replaying history.

---

### 4. Verify that entities are created

After the add-on has been running for a bit:

1. Go to **Settings → Devices & Services → MQTT → Devices**.
2. You should see one device per Vicohome camera, e.g.:

   - `Vicohome Front Driveway`
   - `Vicohome Mid Driveway`
   - `Vicohome Front porch`
   - `Vicohome Generator Shed`
   - `Vicohome Driveway Parking Area`

Each device should contain:

- `Last Event` (sensor)
- `Motion` (binary_sensor)
- `Battery` (sensor)
- `WiFi` (sensor)
- `Online` (binary_sensor)

You can also check via **Developer Tools → States** and search for `vicohome`.

---

## Entities & Topics

By default the add-on:

- Publishes per-camera JSON events to:
  - `vicohome/<safe_camera_id>/events`
  - `vicohome/<safe_camera_id>/state`
  - `vicohome/<safe_camera_id>/motion` (`ON`/`OFF`)
  - `vicohome/<safe_camera_id>/telemetry` (battery/WiFi/online details)
  - (Optional) `vicohome/<safe_camera_id>/webrtc_request` / `webrtc_ticket` / `webrtc_status` when the experimental WebRTC export is enabled.

- Registers MQTT Discovery entries for:

  - `sensor.vicohome_<camera>_last_event`
  - `binary_sensor.vicohome_<camera>_motion`
  - `sensor.vicohome_<camera>_battery`
  - `sensor.vicohome_<camera>_wifi`
  - `binary_sensor.vicohome_<camera>_online`

Where `<camera>` is a normalized ID (lowercase, non-alphanumerics replaced with `_`).

The **Last Event** sensor exposes attributes such as:

- `timestamp`
- `imageUrl` (signed thumbnail URL)
- `videoUrl` (M3U8 link)
- `eventType`
- `deviceName` / `serialNumber`
- and other fields from the Vicohome API.

All of this data ultimately comes from `vico-cli` – this add-on just forwards and reshapes it.

### Live view / WebRTC tickets

The add-on now exposes a lightweight MQTT command channel for Vicohome's official P2P/WebRTC flow (documented in the [`open-p2p-connection`, `get-webrtc-ticket`, and `close-p2p-connection` discovery files at commit `67164de`](https://github.com/dydx/vico-cli/tree/67164debd60ff658237da8b3047da9a9e08e6bb5/endpoints)).

- Send `vicohome/<safe_camera_id>/cmd/live_on` to open a P2P session and fetch the latest ticket for that camera.
  - Optional payload: `{"stream": "sub"}` to request the SUB stream instead of MAIN (defaults to MAIN).
- Read the ticket JSON (as returned by `getWebrtcTicket`) from `vicohome/<safe_camera_id>/webrtc_ticket` and hand it to go2rtc, a custom bridge, etc.
- Watch `vicohome/<safe_camera_id>/p2p_status` for JSON state updates like `starting`, `ticket`, `error`, `closed`.
- When you're done viewing, publish `vicohome/<safe_camera_id>/cmd/live_off` to call Vicohome's close endpoint and free the session.

Every `live_on` request uses the new `vico-cli p2p session` helper, which opens the P2P connection, retrieves the ticket, and logs the raw response. The add-on never bypasses Vicohome's cloud — it simply exposes those documented endpoints through MQTT so the rest of your stack can consume them.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Experimental: P2P / WebRTC ticket export

The add-on now exposes the WebRTC / P2P "ticket" data that the latest `vico-cli` can request from Vicohome. When enabled it will run `vico-cli webrtc ticket --serial <camera_id> --format json`, enrich the JSON with metadata, and publish the payload to MQTT so an external tool (go2rtc, a custom script, etc.) can start a direct session.

### Configuration knobs

- `webrtc_enabled` – opt-in gate (default: `false`). Nothing WebRTC-related runs unless this is `true`.
- `webrtc_mode` – `off`, `poll`, or `on_demand` (default: `on_demand`).
  - `on_demand`: the add-on listens for MQTT requests and only wakes cameras when you ask for a ticket (best for battery cams).
  - `poll`: fetch a fresh ticket for every known camera every `webrtc_poll_interval` seconds.
  - `off`: keep everything disabled even if `webrtc_enabled` is `true`.
- `webrtc_poll_interval` – seconds between poll runs (default 120s). Ignored unless `webrtc_mode` = `poll`.

### MQTT topics & workflow

For each camera (identified by the existing `<safe_id>` that shows up in `vicohome/<safe_id>/state`):

- `vicohome/<safe_id>/webrtc_request` – publish any payload (even an empty string) to this topic to trigger an on-demand ticket fetch. Used only when `webrtc_mode` = `on_demand`.
- `vicohome/<safe_id>/webrtc_ticket` – receives the JSON ticket plus helper fields (`camera_id`, `deviceName`, `ts`). Tickets are **not retained** because they expire quickly.
- `vicohome/<safe_id>/webrtc_status` – optional status messages (e.g. `{"status":"ok","message":"ticket published ..."}`) so automations can tell success vs failure.

Every payload references the same `<safe_id>` / `camera_id` that MQTT discovery already uses. Use the `vicohome_<safe_id>` naming convention when defining go2rtc sources so everything lines up.

### Basic go2rtc tie-in idea

The add-on intentionally stops at "publish the ticket" – you are free to wire it into go2rtc however you prefer. One pattern is:

1. Run in `on_demand` mode so you only wake cameras when a viewer connects.
2. Have go2rtc (or an HA automation) publish an empty payload to `vicohome/front_driveway/webrtc_request` when it needs a fresh ticket.
3. Listen for `vicohome/front_driveway/webrtc_ticket`, parse the JSON, and call go2rtc's HTTP API to update a custom `webrtc` source:

   ```yaml
   # Pseudo automation
   trigger:
     - platform: mqtt
       topic: "vicohome/front_driveway/webrtc_ticket"
   action:
     - service: rest_command.go2rtc_apply_ticket
       data:
         payload: "{{ trigger.payload }}"  # forward ticket JSON to your helper script / go2rtc endpoint
   ```

4. Configure go2rtc with a source named `vicohome_front_driveway` that expects those tickets.

Feel free to adapt the pattern: the add-on simply guarantees that requests go in via `/webrtc_request` and tickets come out via `/webrtc_ticket`, leaving the rest to your automations. Remember that frequent polling may drain batteries, so `on_demand` mode is recommended unless you have cameras on constant power.

### Optional go2rtc POSTs

If you also enable the `go2rtc_enabled` option, every ticket that gets published to MQTT is mirrored to `http://go2rtc:1984/api/stream` (override via `go2rtc_url`). The payload matches this structure:

```json
{
  "name": "vicohome_front_driveway",
  "safe_id": "front_driveway",
  "camera_id": "SERIAL123",
  "camera_name": "Front Driveway",
  "ts": "2024-05-01T12:34:56Z",
  "ticket": { ...raw `vico-cli webrtc ticket` JSON... }
}
```

The `name` comes from `go2rtc_stream_prefix + <safe_id>` so it lines up with the MQTT discovery naming. go2rtc accepts the POST and can use the embedded `ticket` JSON to refresh a `webrtc` input via automations, scripts, or a custom go2rtc build. A simple workflow:

1. Enable `webrtc_enabled: true`, `webrtc_mode: on_demand`, and `go2rtc_enabled: true`.
2. Have go2rtc (or an automation) publish to `vicohome/<safe_id>/webrtc_request` when a viewer connects.
3. go2rtc receives the mirrored POST with the full ticket JSON and can update a stream named `vicohome_<safe_id>` without needing another MQTT listener.

You can continue to consume the MQTT ticket topic in parallel; the HTTP POST is just a convenience so go2rtc-based setups have a consistent entry point even if they cannot subscribe to MQTT directly.

---

## Optional: Vicohome dashboard

This dashboard gives you:

- A **Last Events** card with one block per camera:
  - Friendly name
  - “Last event: X minutes ago” + local timestamp
  - Event type
  - Thumbnail image
  - “Watch clip” link, when available
- A **Camera Health** card per camera:
  - Online/Offline
  - Battery %
  - WiFi dBm
  - Last event age & timestamp

### Prerequisites

- [HACS](https://hacs.xyz/) installed
- `config-template-card` installed from HACS:
  - HACS → Frontend → `+` → search `Config Template Card`

Make sure `config-template-card` is **added as a resource** (HACS usually does this automatically).

### Add the dashboard

1. Go to **Settings → Dashboards**.
2. Click **Add Dashboard**.
3. Name it e.g. `Vicohome`.
4. Open that new dashboard → **⋮ → Edit dashboard → ⋮ → Raw configuration editor**.
5. Replace everything with:

```yaml
title: Vicohome
views:
  - title: Vicohome
    path: vicohome
    icon: mdi:cctv
    cards:
      # ==============================
      # Card 1: Last events + thumbnails
      # ==============================
      - type: custom:config-template-card
        entities:
          - sun.sun
        card:
          type: markdown
          title: Vicohome Last Events
          content: >
            {% set sensors = states.sensor
                 | selectattr('entity_id', 'search', '^sensor\.vicohome_.*_last_event$')
                 | list %}

            {% if not sensors %}
            _No Vicohome cameras found yet. Make sure the Vicohome Bridge add-on is running and events have been pulled._
            {% endif %}

            {% for s in sensors %}
            {% set raw_name = s.name %}
            {% set cam_name = raw_name | replace(' Last Event', '') %}

            {% set ts  = state_attr(s.entity_id, 'timestamp') %}
            {% set img = state_attr(s.entity_id, 'imageUrl') %}
            {% set vid = state_attr(s.entity_id, 'videoUrl') %}
            {% set etype = state_attr(s.entity_id, 'eventType') or state_attr(s.entity_id, 'type') %}

            {% if ts %}
              {% set ts_local = as_timestamp(ts) | as_datetime | as_local %}
              {% set ts_rel = ts_local | relative_time %}
            {% else %}
              {% set ts_local = None %}
              {% set ts_rel = 'No events yet' %}
            {% endif %}

            {% if not loop.first %}
            ---
            {% endif %}

            ### {{ cam_name }}

            **Last event:** {{ ts_rel }}
            {% if ts_local %}_ ({{ ts_local }})_{% endif %}

            {% if etype %}
            **Type:** `{{ etype }}`
            {% endif %}

            {% if img %}
            ![thumb]({{ img }})
            {% else %}
            _No image available_
            {% endif %}

            {% if vid %}
            [▶ Watch clip]({{ vid }})
            {% endif %}

            {% endfor %}

      # ==============================
      # Card 2: Camera health overview
      # ==============================
      - type: custom:config-template-card
        entities:
          - sun.sun
        card:
          type: markdown
          title: Vicohome Camera Health
          content: >
            {% set sensors = states.sensor
                 | selectattr('entity_id', 'search', '^sensor\.vicohome_.*_last_event$')
                 | list %}

            {% if not sensors %}
            _No Vicohome cameras found yet._
            {% endif %}

            {% for s in sensors|sort(attribute='name') %}
            {% set raw_name = s.name %}
            {% set cam_name = raw_name | replace(' Last Event', '') %}

            {% set batt_id   = s.entity_id | replace('_last_event', '_battery') %}
            {% set wifi_id   = s.entity_id | replace('_last_event', '_wifi') %}
            {% set online_id = s.entity_id
                               | replace('sensor.', 'binary_sensor.')
                               | replace('_last_event', '_online') %}

            {% set batt   = states(batt_id) %}
            {% set wifi   = states(wifi_id) %}
            {% set online = states(online_id) %}

            {% set ts  = state_attr(s.entity_id, 'timestamp') %}
            {% if ts %}
              {% set ts_local = as_timestamp(ts) | as_datetime | as_local %}
              {% set ts_rel   = ts_local | relative_time %}
              {% set last_str = ts_rel ~ ' (' ~ ts_local ~ ')' %}
            {% else %}
              {% set last_str = 'No events yet' %}
            {% endif %}

            {% if not loop.first %}
            ---
            {% endif %}

            ### {{ cam_name }}

            **Status:** {% if online == 'on' %}✅ Online{% elif online == 'off' %}❌ Offline{% else %}Unknown{% endif %}

            **Battery:** {% if batt in ['unknown', 'unavailable', ''] %}Unknown{% else %}{{ batt }}%{% endif %}

            **WiFi:** {% if wifi in ['unknown', 'unavailable', ''] %}Unknown{% else %}{{ wifi }} dBm{% endif %}

            **Last event:** {{ last_str }}

            {% endfor %}
```

6. Click **Save**, then exit edit mode.

---

## Troubleshooting

### 1. No Vicohome entities show up

**Symptoms:**

- Searching `vicohome` in Developer Tools → States shows nothing
- MQTT integration has no “Vicohome …” devices

**Check:**

1. Add-on logs (Vicohome Bridge → **Log**):

   - Verify `Vicohome Bridge configuration:` prints your settings.
   - You should see something like:

     ```text
     Using MQTT broker at core-mosquitto:1883, base topic: vicohome
     Running initial device discovery via 'vico-cli devices list --format json'...
     Ensuring discovery for device 'Front Driveway' (a628237d...)
     ```

   - If you see an error like `You must set 'email' and 'password'`, fix the config.

2. Confirm the **MQTT integration** is configured and working
   - Try publishing a test message using Developer Tools → MQTT.

3. Make sure your **bridge Vicohome account** actually sees the cameras.
   - Open the Vicohome app while logged in as the bridge account and confirm all cameras appear.
   - If not, log in with your main account and ensure all cameras are **shared** to the bridge user.

---

### 2. MQTT “not authorised” / `received null username or password`

If Mosquitto logs show:

```text
error: received null username or password for unpwd check
Client core-mosquitto.Vicohome disconnected, not authorised.
```

Then:

- Your Mosquitto broker requires authentication, but the Supervisor **MQTT service** is not exposing credentials correctly, or you misconfigured the MQTT integration.

Fix:

1. Ensure the MQTT integration is connected to the same broker as the Mosquitto add-on and using valid credentials.
2. Restart:
   - Mosquitto broker
   - MQTT integration (Configure → Reload)
   - Vicohome Bridge add-on

The bridge uses the credentials provided by `bashio::services mqtt`.

---

### 3. Cameras exist but no events / thumbnails

**Symptoms:**

- `sensor.vicohome_*_last_event` exists, but:
  - `timestamp` attribute is missing or `Unknown`
  - `imageUrl` is empty
  - Dashboard shows “No events yet / No image available”

Possible causes:

1. The **bridge account** has not recorded events yet  
   - When you first switch to a new bridge account, Vicohome may only start tracking events from that account’s perspective.
   - Wait for new motion events or trigger motion in front of the camera.

2. `vico-cli events list --format json` returns empty on the backend  
   - Check the add-on logs: they will show the first 200 chars of the events JSON each poll.
   - If Vicohome is rate-limiting or returning non-JSON, the log will say so.

---

### 4. Some cameras missing, or duplicate/ghost entities

If you changed the add-on version or discovery IDs at some point, Home Assistant may still have **old** MQTT entities.

As of v1.1.9 the add-on automatically refreshes the MQTT discovery payloads every few minutes. If you delete a Vicohome entity or device from Home Assistant, it should reappear shortly after telemetry or an event arrives.

Fix:

1. Stop the **Vicohome Bridge** add-on.
2. Go to **Settings → Devices & Services → MQTT → Devices**.
3. For each device whose name starts with **Vicohome**:
   - Click it → **⋮ → Delete device**.
4. Reload the MQTT integration (Configure → Reload).
5. Start the **Vicohome Bridge** add-on again.

The forced restart is rarely necessary now, but it guarantees Home Assistant clears out the stale MQTT topics before the bridge republishes discovery with the current IDs.

---

### 5. Dashboard errors: “Configuration error / No entities defined”

This usually means **config-template-card** is not installed or not configured as a resource.

Fix:

1. Install **Config Template Card** via HACS:
   - HACS → Frontend → `+` → search `Config Template Card`.
2. Restart Home Assistant or reload Lovelace resources.
3. Ensure the card type in YAML is exactly:

   ```yaml
   type: custom:config-template-card
   ```

4. Make sure each card has an `entities:` block with at least one entity (e.g. `sun.sun`).

---

## Credits

- Huge thanks to **[@dydx](https://github.com/dydx)** for creating and maintaining
  [`vico-cli`](https://github.com/dydx/vico-cli) – this add-on is basically
  “`vico-cli` + MQTT + Home Assistant glue.”
- Vicohome Bridge add-on + dashboard by the community (feel free to fork, tweak, and PR).

Issues / ideas / PRs welcome!
