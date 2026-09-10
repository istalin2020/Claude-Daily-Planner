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

Open `DailyPlanner/Services/CloudFoodAnalyzer.swift` and replace the two
placeholders near the top:

```swift
static let workerBaseURL = "https://dailyplanner-food.<your-subdomain>.workers.dev"
static let appToken      = "the-random-string-from-step-3"
```

No trailing slash on the URL. Until these are filled in, the app silently stays
on on-device recognition, so nothing breaks in the meantime.

Build and run, then try both ways into it from **Food Tracker → any meal**:

- the **camera icon** — photograph your plate
- the **+ icon** — type a dish name such as `valaikkai bajji`

Either way you should get the dish identified with a full nutrition breakdown.

---

## Optional — cap usage per device

Without this, one person could in theory hammer the service. To cap each device
at 40 analyses a day:

```bash
npx wrangler kv namespace create RATE_LIMIT
```

Paste the printed `id` into `wrangler.toml`, uncomment the three
`[[kv_namespaces]]` lines, then `npx wrangler deploy` again. Adjust the number
with the `DAILY_LIMIT` var in the same file.

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
| "This build can't reach the analysis service" | `APP_TOKEN` in the app ≠ the Worker secret | Re-check Step 4 |
| "Smart analysis isn't set up in this build yet" | Placeholders still in `CloudFoodAnalyzer.swift` | Step 4 |
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
