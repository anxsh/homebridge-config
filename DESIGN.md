# Design

## Architecture

Single Docker container (`homebridge/homebridge`, host networking) running
on `aksa`. Homebridge state (bridge identity, installed plugins, accessory
cache) lives in `./config/`, bind-mounted into the container so it survives
recreation. No database, no build step — the official image is the whole
stack.

## Changelog

### 2026-08-17 — Added `homebridge-omlet` for the coop Autodoor

**What:** Installed `homebridge-omlet` (npm) into the Homebridge container
and added an `OmletCoop` platform block to `config/config.json`,
authenticating via a bearer API key generated at
smart.omlet.com/developers rather than the plugin's email/password login
option. Exposes the coop door as a HomeKit garage-door accessory.

**Why:** User wants the Omlet Autodoor controllable/automatable from Apple
Home alongside the Nest thermostats already bridged here, instead of a
separate Omlet app. The bearer-token auth path was chosen over
email/password because it's the same "official API, not stored account
credentials" pattern already used for `homebridge-google-nest-sdm` —
avoids putting the Omlet account password in `config.json`.

**Tradeoff:** Unlike the SDM plugin's OAuth, `homebridge-omlet` still
polls Omlet's cloud (default every 30s) rather than using event push, so
door-state changes made outside HomeKit take up to that long to reflect.
The plugin itself also explicitly disclaims responsibility for flock
safety — don't rely on HomeKit's reported door state alone.

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

### 2026-08-17 — Switched to `homebridge-google-nest-sdm`, dropping Protects

**What:** Replaced `homebridge-nest` with `homebridge-google-nest-sdm`
(potmat/homebridge-google-nest-sdm), authenticating via Google's official
Smart Device Management (SDM) OAuth flow — `clientId`/`clientSecret` from a
Cloud Console OAuth client, a Device Access Console project (`projectId`,
one-time $5 registration), a `refreshToken` obtained via the OAuth
authorization-code flow, and a Pub/Sub pull `subscriptionId` for device
events. Nest Protects are no longer bridged into Apple Home.

**Why:** `homebridge-nest`'s cookie auth broke (`USER_LOGGED_OUT`) after
running for less than a day, confirming the brittleness flagged in the
2026-08-17 entry above. The user decided Protect support in Apple Home
wasn't worth the recurring manual cookie-recapture — see the tradeoff noted
in that entry.

**Gotchas hit during setup (for next time this needs to be redone):**
- The SDM API's official `redirect_uri=https://www.google.com` from Google's
  own docs now fails with `redirect_uri_mismatch` — Google blocklists
  `google.com` domains as custom OAuth redirect targets. Use
  `http://localhost` instead (works on Web-application-type OAuth clients
  without needing to own/verify a domain); the browser will fail to connect
  after consent, but the `code=` param is still in the address bar.
- The Pub/Sub topic must be created manually in the same GCP project as the
  OAuth client, then registered in the Device Access Console (it does not
  auto-create one). The publisher principal to grant on the topic is the
  Google group `sdm-publisher@googlegroups.com` (not a service account —
  `smart-device-management-issue@system.gserviceaccount.com`, mentioned in
  some older guides, does not exist). Granting it via the Cloud Console
  "Add Principal" UI can reject valid Google-managed principals with an
  "must be associated with an active account" error; `gcloud pubsub topics
  add-iam-policy-binding` works around it.
- With the OAuth consent screen in "Testing" status, refresh tokens expire
  after 7 days (`refresh_token_expires_in` in the token response) — worse
  than the cookie method we were trying to escape. Fix: Cloud Console →
  OAuth consent screen → **Publish App**. For a personal/single-user SDM
  app this does not require completing Google's verification review (no
  privacy policy, demo video, etc.) — publishing alone drops the 7-day cap
  and the resulting refresh token has no expiry field. Re-run the
  authorization flow once more after publishing to get a token issued
  under the new status; tokens issued while still in Testing keep their
  original 7-day expiry even after the app is published.
