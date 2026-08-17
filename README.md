# homebridge-config

Homebridge, running in Docker on `aksa` (Raspberry Pi 4), to bridge Nest
thermostats into Apple Home. Nest Protects are not bridged — see
`DESIGN.md` for why.

## Why this plugin

This repo uses
[`homebridge-google-nest-sdm`](https://github.com/potmat/homebridge-google-nest-sdm),
which talks to Google's official Smart Device Management (SDM) API via
OAuth — no scraped browser cookies. The tradeoff is that SDM doesn't expose
Nest Protect at all (only thermostats, cameras, doorbells, and displays);
the only plugin that supports Protect (`homebridge-nest`) requires
reverse-engineered cookie auth that broke within a day in practice. See
`DESIGN.md` for the full history and tradeoffs.

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
under Config UI's user settings) and install the **GoogleNestSDM** plugin
(`homebridge-google-nest-sdm`) from the Plugins tab.

### 3. Get SDM OAuth credentials for the plugin

Follow the `homebridge-google-nest-sdm`
[setup instructions](https://github.com/potmat/homebridge-google-nest-sdm#where-do-the-config-values-come-from).
At a high level:

1. Create a Google Cloud project, enable the Smart Device Management API,
   and create a **Web application**-type OAuth 2.0 Client ID
   (`clientId`/`clientSecret`).
2. Register a project in the
   [Device Access Console](https://console.nest.google.com/device-access)
   ($5 one-time fee) linked to that OAuth client — gives you `projectId`.
3. Create a Pub/Sub topic in the same GCP project, grant the Google group
   `sdm-publisher@googlegroups.com` the **Pub/Sub Publisher** role on it
   (via `gcloud pubsub topics add-iam-policy-binding` if the Cloud Console
   UI rejects the principal), and register the topic in the Device Access
   Console under "Enable Pub/Sub topic for Events".
4. Create a **Pull** subscription on that topic in Cloud Console → Pub/Sub
   → Subscriptions — gives you `subscriptionId`
   (`projects/<gcp-project-id>/subscriptions/<name>`).
5. In Cloud Console → OAuth consent screen, click **Publish App** (skip
   Google's verification review — not required for personal use). This
   matters: while the consent screen is still in "Testing" status, refresh
   tokens expire after 7 days.
6. Authorize your Nest account using the partner-connections URL (built
   from `client_id` + `projectId`, scopes `sdm.service` +
   `pubsub`, `redirect_uri=http://localhost` — Google blocklists
   `https://www.google.com` as a redirect target despite Google's own docs
   suggesting it) and exchange the resulting `code` for a `refreshToken`
   via the OAuth token endpoint.
7. Paste `clientId`, `clientSecret`, `projectId`, `refreshToken`,
   `subscriptionId`, and `gcpProjectId` into `config/config.json` under the
   `homebridge-google-nest-sdm` platform (or the plugin's settings form in
   Config UI, which writes to the same file).

See `DESIGN.md`'s 2026-08-17 changelog entry for gotchas hit doing this the
first time.

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
  real `config.json` (bridge identity + SDM OAuth credentials), Config UI
  credentials, plugin installs, accessory cache, and backups all live only
  on `aksa` and are never committed.
- The populated `config.json` values (SDM OAuth credentials, Config UI
  login, bridge PIN) are saved in the password manager as a backup.
