# Vicohome Bridge Add-on for Home Assistant

Repo: <https://github.com/KIWIDUDE564/vicohome-bridge-addon>

> ⚠️ **Unofficial integration.**
> This add-on is a thin wrapper around the open-source
> [`vico-cli`](https://github.com/dydx/vico-cli) project by **dydx**.
> It is **not** affiliated with Vicohome or the vico-cli author.

The Vicohome Bridge add-on logs into the Vicohome cloud with `vico-cli`, polls the
API for camera telemetry + events, and republishes everything to MQTT so Home
Assistant can consume it through automatic MQTT discovery.

It focuses on four things:

- Reliable authentication (with explicit multi-region support)
- Device telemetry publishing (battery, Wi-Fi, online state, IP)
- Event polling + optional history bootstrap so the "last event" sensors always
  populate
- MQTT discovery and the prebuilt HA dashboards that ship with this repo

---

## Strongly recommended account setup

For safety and sanity:

1. Keep your existing Vicohome account as your **main account**.
2. Create a **new “bridge” account** in the Vicohome app (e.g. `homeassistant_bridge@example.com`).
3. From the main account, **share all cameras** to the bridge account.
4. Use **only** the bridge account credentials in this add-on.

This keeps your main login out of Home Assistant and also makes it easy to
revoke/remove access later if needed.

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
- A markdown dashboard showing thumbnails + camera health

---

## Requirements

- **Home Assistant OS** or **Supervised** (add-on support required)
- **MQTT broker** available to Home Assistant
  - Recommended: the official **Mosquitto broker add-on** (`core-mosquitto`)
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

1. Go to **Settings → Add-ons → Add-on Store** in Home Assistant.
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

The add-on automatically uses the broker host/port/credentials from service discovery, so no extra configuration is required inside `options.json`.

---

### 4. Optional dashboard

Install the `config-template-card` via HACS and copy the Lovelace resources/snippets from the `dashboards/` folder (if you cloned the repo) so you can see last-event thumbnails + camera health on a single panel.

---

## MQTT topics & discovery recap

For each camera with safe ID `<safe_id>` (derived from its serial number) the add-on publishes:

- `vicohome/<safe_id>/events` – raw Vicohome event JSON
- `vicohome/<safe_id>/state` – same payload, retained, used for the Last Event sensor
- `vicohome/<safe_id>/motion` – short `ON`/`OFF` pulses for motion automations
- `vicohome/<safe_id>/telemetry` – battery level, Wi-Fi signal, online state, IP
- `vicohome/bridge/status` – retained availability topic shared by all HA entities

MQTT discovery payloads are refreshed every few minutes so deleted HA entities are recreated automatically.

---

## Rebuild after pulling new commits

If you're running this repository from a local checkout (instead of the published
Supervisor store version), you need to **rebuild** the add-on every time you
pull new commits:

1. Go to **Settings → Add-ons → Vicohome Bridge**.
2. Click **Rebuild** (or **Install** again) so Home Assistant repackages the
   updated `run.sh`, vendored `vico-cli`, and configuration defaults.
3. Start the add-on once the rebuild finishes.

This ensures fixes like the BusyBox `grep` compatibility patches and regional
tweaks actually make it into your running container.

---

## Limitations

- The add-on only bridges Vicohome's cloud events, telemetry, and discovery data.
  Earlier experiments around direct-stream/ticket export have been removed so the
  focus stays on the stable cloud workflows described above.
