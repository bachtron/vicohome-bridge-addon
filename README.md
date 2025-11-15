# Vicohome Bridge Add-ons

This repository contains a Home Assistant Supervisor add-on that bridges Vicohome
to Home Assistant using the Vicohome CLI.

## Add-on: Vicohome Bridge

The Vicohome Bridge add-on:

- Logs into Vicohome using your email and password.
- Exposes a small HTTP API inside your Home Assistant network:
  - `GET /events` – returns Vicohome events as JSON
  - `GET /latest_video` – redirects to the selected event's `videoUrl`
- Lets you create a Lovelace button that opens the latest video in the HA app or browser.

### Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** (three dots) in the top right → **Repositories**.
3. Add this repository URL:

   `https://github.com/YOUR_GITHUB_USERNAME/vicohome-bridge-addon`

4. The **Vicohome Bridge** add-on will appear under the **Vicohome Bridge Add-ons** section.
5. Click it → **Install**.

### Configuration

The add-on has these options:

- `vicohome_email`: Your Vicohome login email.
- `vicohome_password`: Your Vicohome login password.
- `event_index`: Which event to use from the event list (0 = newest).
- `http_port`: Port for the internal HTTP server (default: 8099).

After configuration, start the add-on and then:

- Open `http://homeassistant.local:8099/events` to see raw JSON events.
- Open `http://homeassistant.local:8099/latest_video` to be redirected to the latest event's video.

You can create a Lovelace button that navigates to:

`http://homeassistant.local:8099/latest_video`

to open the latest video from the HA app or browser.
