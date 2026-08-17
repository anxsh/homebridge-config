# homebridge-config

Homebridge, running in Docker on `aksa` (Raspberry Pi 4), to bridge Nest
thermostats and Nest Protects into Apple Home.

## Why this plugin

Google's official Nest integration (the Smart Device Management / SDM API)
does not expose Nest Protect at all — only thermostats, cameras, doorbells,
and displays. The only Homebridge plugin that supports Protect is
[`homebridge-nest`](https://github.com/chrisjshull/homebridge-nest), which
talks to Nest's unofficial API using a Google account cookie instead of
OAuth. It covers both thermostats and Protects in one plugin, so that's what
this repo is set up for. See `DESIGN.md` for details and the tradeoffs.

## Setup

### 1. Start Homebridge

```
make up
```

This starts the official `homebridge/homebridge` container on host
networking (required for HomeKit/mDNS discovery) and creates `./config/`
with persistent state (bridge identity, installed plugins, accessory
cache). `./config/config.json` already exists with a randomly generated
bridge username/PIN — leave those as-is.

### 2. Open the Config UI

```
make ui
```

Log in (default credentials: `admin` / `admin` — change these immediately
under Config UI's user settings) and install the **Nest** plugin
(`homebridge-nest`) from the Plugins tab.

### 3. Get Google auth credentials for the Nest plugin

Follow the `homebridge-nest`
[Google account cookie auth steps](https://github.com/chrisjshull/homebridge-nest#configuration):

1. Open an incognito browser window with DevTools open on the Network tab.
2. Log in at `home.nest.com` with your Google account.
3. Find the `issueToken` request — copy its full request URL.
4. Find the `iframe` request for `oauth2/iframe` — copy its full `cookie`
   request header.
5. Paste these into `config/config.json` under `platforms[0].googleAuth` as
   `issueToken` and `cookies` (or paste them into the plugin's settings form
   in the Config UI, which writes to the same file).

These cookies can expire (Google may invalidate them on password change,
security events, etc.) — if the plugin stops authenticating, redo this
step.

### 4. Restart and pair with Apple Home

```
make restart
```

Then in the Home app on iPhone/iPad: **Add Accessory** → **More options** →
select the Homebridge bridge → enter the PIN from `config/config.json`.

## Troubleshooting

### Homebridge doesn't show up in Apple Home

Bridge discovery relies on mDNS/Bonjour, which is multicast and doesn't
cross VLANs by default. If the Pi and your phone are on different VLANs
(e.g. an IoT VLAN vs. your main network), the phone will never see the
advertisement even though Homebridge is running fine.

You can confirm the bridge really is broadcasting from the Pi's side with:

```
avahi-browse -a -t
```

Look for a `_hap._tcp` entry with `sf=1` in its TXT record (unpaired,
discoverable). If that shows up but the Home app still can't find it, the
traffic isn't reaching your phone's VLAN — enable mDNS relaying on your
router/gateway (on UniFi: **Settings → Advanced → Multicast DNS**, set to
**Auto**) so mDNS traffic is relayed between VLANs.

## Common tasks

| Command        | Description                                    |
|----------------|-------------------------------------------------|
| `make up`      | Start Homebridge                                |
| `make down`    | Stop and remove the container                   |
| `make restart` | Restart the container                           |
| `make logs`    | Follow container logs                           |
| `make pull`    | Pull the latest Homebridge image                |
| `make update`  | Pull latest image and recreate the container    |
| `make ps`      | Show container status                           |
| `make shell`   | Open a shell inside the running container       |
| `make ui`      | Print the Config UI URL                         |

## Notes

- `.gitignore` ignores everything under `config/` except
  `config/config.json.example`, which is the only tracked file there. The
  real `config.json` (bridge identity + Google auth cookies), Config UI
  credentials, plugin installs, accessory cache, and backups all live only
  on `aksa` and are never committed.
