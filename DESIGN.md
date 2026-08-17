# Design

## Architecture

Single Docker container (`homebridge/homebridge`, host networking) running
on `aksa`. Homebridge state (bridge identity, installed plugins, accessory
cache) lives in `./config/`, bind-mounted into the container so it survives
recreation. No database, no build step — the official image is the whole
stack.

## Changelog

### 2026-08-17 — Chose `homebridge-nest` (unofficial API) over the official SDM plugin

**What:** Set up Homebridge to use `homebridge-nest`
(chrisjshull/homebridge-nest), authenticating via a scraped Google account
cookie (`issueToken` + `cookies`), rather than
`homebridge-google-nest-sdm`, which uses Google's official OAuth-based Smart
Device Management API.

**Why:** The user wants both Nest thermostats and Nest Protects in Apple
Home. Google's SDM API — the only officially supported integration path —
does not expose Protect data at all (it only ever covered thermostats,
cameras, doorbells, and displays). `homebridge-nest` is the only maintained
plugin that surfaces Protect, and it happens to also cover thermostats, so
one plugin satisfies both device types.

**Tradeoff:** `homebridge-nest`'s Google-account auth is unofficial
(reverse-engineered cookie extraction from browser DevTools, not OAuth) —
Google broke the previous refresh-token method in October 2022, and the
cookie method could similarly stop working without notice. The official SDM
API route (OAuth, Device Access Console registration, Pub/Sub for events)
is more stable but was rejected because it cannot see Protect devices at
all — there's no way to get Protects into Homebridge through it. If Protect
support in Apple Home turns out not to matter in practice, revisit and
switch to `homebridge-google-nest-sdm` for a more durable thermostat-only
integration.
