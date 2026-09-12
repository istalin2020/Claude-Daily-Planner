# Smart Food Analysis — setup

This Worker sits between the Daily Planner app and OpenAI. PRO users either
photograph a meal or type a dish name; the Worker sends it to **GPT-5 nano**,
which identifies every item and returns portions, calories and nutrition.

**The OpenAI key never goes in the app.** A key inside an iOS binary can be
extracted in minutes and used to run up your bill. It lives here as a Cloudflare
secret. The app instead sends an `APP_TOKEN`, which you can rotate any time
without shipping a new build.

Free users never touch this — their food is estimated entirely on device.

---

## What it costs

GPT-5 nano is **$0.05 per million input tokens and $0.40 per million output
tokens**. One food photo is roughly 1,100 input and 400 output tokens; a typed
dish name is cheaper still, since there is no image to read.

| | |
|---|---|
| Per photo | about **$0.0002** — roughly **2 paise** |
| A PRO user logging 4 photos a day, for a month | about **$0.024** — roughly **₹2** |
| 1,000 PRO users doing that | about **$24/month** |

Cloudflare Workers' free plan covers 100,000 requests a day, which is far more
than this will ever need.

---

## Step 1 — Get an OpenAI API key

1. Go to **platform.openai.com** and sign in (or sign up).
2. **Settings → Billing** → add a payment method and put **$5** of credit on it.
   Without credit the API returns errors even though the key is valid.
3. **API keys → Create new secret key**. Name it `daily-planner-food`.
4. Copy it now — starts with `sk-...`. OpenAI will not show it again.

While you're there, set **Settings → Limits → monthly budget** to something like
**$10**. It's a hard stop if anything ever goes wrong.

## Step 2 — Deploy the Worker

You already have Cloudflare from the Daily Quote Reminder app, so this is the
same flow. From the `worker/` folder in this repo:

```bash
cd worker
npm install
npx wrangler login          # opens the browser, same account as before
npx wrangler deploy
```

Wrangler prints the URL it deployed to. Copy it — it looks like:

```
https://dailyplanner-food.<your-subdomain>.workers.dev
```

## Step 3 — Set the two secrets

Make up an app token first — any long random string. On a Mac:

```bash
openssl rand -hex 24
```

Then set both secrets (each command prompts you to paste the value):

```bash
npx wrangler secret put OPENAI_API_KEY   # paste the sk-... key from Step 1
npx wrangler secret put APP_TOKEN        # paste the random string you just made
```

Check it worked:

```bash
curl https://dailyplanner-food.<your-subdomain>.workers.dev/health
```

You want `{"ok":true,"configured":true,"model":"gpt-5-nano"}`. If `configured`
is `false`, a secret didn't save — run Step 3 again.

## Step 4 — Put both values into the app

**This repo is public, so the values must not be committed.** They go in a
gitignored file instead, which also means `git pull` never wipes them — git
leaves untracked files alone.

Just build once (**⌘B**). A build phase creates
`DailyPlanner/Services/CloudFoodSecrets.swift` from the committed template and
tells you so with a warning. Then open that file in Xcode and edit the two
values:

```swift
static let workerBaseURL = "https://dailyplanner-food.<your-subdomain>.workers.dev"
static let appToken      = "the-random-string-from-step-3"
```

No trailing slash on the URL. Build again and you're done.

**Don't create the file with Xcode's "New File"** — the project already has a
reference to it, and a second one causes *"invalid redeclaration of
CloudFoodSecrets"*. Let the build phase make it, or copy the template yourself:

```bash
cp DailyPlanner/Services/CloudFoodSecrets.example.swift \
   DailyPlanner/Services/CloudFoodSecrets.swift
```

`CloudFoodSecrets.swift` is in `.gitignore`, so it stays on your Mac and no pull
can overwrite it. The build phase only ever creates it when missing — it never
touches a file that already exists, so your values are safe.

Build and run, then try both ways into it from **Food Tracker → any meal**:

- the **camera icon** — photograph your plate
- the **+ icon** — type a dish name such as `valaikkai bajji`

Either way you should get the dish identified with a full nutrition breakdown.
**Settings → Food Analysis** shows whether smart analysis is active, and a
**Test Connection** button that calls `/health` from the phone.

> **After a re-clone**, the first build recreates `CloudFoodSecrets.swift` from
> the template automatically — you just need to paste your two values back in.

### While testing: the Settings shortcut

DEBUG builds also read the URL and token from
**Settings → Food Analysis → Analysis Service**, which overrides
`CloudFoodSecrets` and is handy for pointing at a different Worker without
touching code. Release builds ignore it entirely — that section isn't even
compiled in — so App Store users always get the values from
`CloudFoodSecrets.swift`. Nothing for them to set up.

---

## Guarding against abuse

The app token ships inside the binary and can be extracted from it, so assume
that eventually someone will find it and try to call your Worker directly. Two
guards make that a non-event. Set up both before you publish.

### 1. OpenAI spending limit — 30 seconds, do this first

**platform.openai.com → Settings → Limits → monthly budget.** Set it to
something you'd shrug at, say **$10**. This is a hard stop: whatever happens
upstream, your bill cannot exceed it. Nothing in the app or Worker to change.

### 2. Per-device daily cap — from the Cloudflare dashboard

Caps each device at 40 analyses a day. The Worker already has the code; it stays
dormant until you give it somewhere to count.

1. **dash.cloudflare.com → Storage & Databases → KV → Create a namespace.**
   Name it `dailyplanner-food-limits` → **Add**
2. Go to **Workers & Pages → dailyplanner-food → Bindings → Add**
3. Choose **KV namespace**. Variable name must be exactly **`RATE_LIMIT`**
   (the Worker looks for that name). Pick the namespace from step 1 → **Add**
4. Still in **Bindings**, **Add** → **Variable (plain text)**, name
   **`DAILY_LIMIT`**, value **`40`**
5. **Deploy**

A device that hits the cap sees *"You've used all 40 food analyses for today.
They reset tomorrow."* Raise or lower it by editing `DAILY_LIMIT` — no code
change. Leave `RATE_LIMIT` unbound and the Worker simply doesn't rate limit.

*(On the CLI the equivalent is `npx wrangler kv namespace create RATE_LIMIT`,
then uncommenting the `[[kv_namespaces]]` block in `wrangler.toml`.)*

### If a token does leak

Set a new `APP_TOKEN` secret on the Worker and put the same value in
`CloudFoodSecrets.swift`, then ship an app update. Published builds carrying the
old token fall back to on-device analysis in the meantime — degraded, not
broken.

### The stronger fix, when you have real subscribers

Verify the App Store receipt in the Worker so only genuine PRO subscribers get
through. That removes the leaked-token problem rather than capping it, but it
means passing receipts from the app, calling Apple's verification endpoint, and
caching the result. Worth doing once the subscriber count justifies it.

---

## Switching models

Change one line in `wrangler.toml` and redeploy — no code edit:

```toml
OPENAI_MODEL = "gpt-5.4-nano"
```

`gpt-5.4-nano` is newer and a bit sharper on hard photos, at $0.20/$1.25 per
million tokens — still well under a rupee per photo.

---

## When something goes wrong

Watch the live logs while you use the app:

```bash
npx wrangler tail
```

| What you see in the app | Cause | Fix |
|---|---|---|
| "This build can't reach the analysis service" | `appToken` in the app ≠ the Worker's `APP_TOKEN` secret | Re-check Step 4 |
| "Smart analysis isn't set up in this build yet" | `CloudFoodSecrets.swift` missing or still has placeholders | Step 4 |
| "Couldn't analyse that photo" / "Couldn't work that dish out" | Check `wrangler tail` — usually no OpenAI credit, or a bad key | Step 1 |
| "The analysis service is busy" | OpenAI rate limit | Wait a moment and retry |
| "You've used all N food analyses for today" | The KV rate limit above | Raise `DAILY_LIMIT` |

Rotating the OpenAI key later: `npx wrangler secret put OPENAI_API_KEY` again and
redeploy. The app doesn't change.

---

## Before you submit to App Store Connect

Photos and typed dish names leave the device on the PRO path, so the privacy
answers need updating in App Store Connect → your app → **App Privacy**:

- Add data type **Photos or Videos**, used for **App Functionality**.
- Mark it **not linked to the user's identity** and **not used for tracking** —
  the Worker sends no name, email or account, only an anonymous per-install id
  used for the daily cap.

The Settings screen already tells users what happens and lets them switch it off,
which keeps this straightforward.

---

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/health` | none | Is it deployed and configured |
| `POST` | `/analyze` | `X-App-Token` | Analyse a photo or a dish name |

`POST /analyze` body — send **either** `image` **or** `dishName`:

```jsonc
{
  "image": "<base64 JPEG>",       // photo path
  "mimeType": "image/jpeg",
  "dishName": "Valaikkai bajji",  // typed path — use instead of image
  "mealName": "Snacks",
  "deviceID": "<uuid>",           // anonymous, rate limiting only
  "answers": [                     // second pass only
    { "prompt": "How many did you have?", "answer": "4 pieces" }
  ],
  "note": "no sugar added"
}
```

Both return the same shape, so the app renders one result screen either way.
