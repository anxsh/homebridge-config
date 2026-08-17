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

- `config/config.json` (real bridge identity + Google auth cookies) is
  gitignored — never commit it. `config/config.json.example` is the tracked
  template.
- `config/persist/`, `config/node_modules/`, and other runtime state created
  by the container are also gitignored.
