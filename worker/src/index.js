/**
 * Daily Planner — Smart Food Analysis Worker
 * ------------------------------------------
 * A thin proxy that sits between the iOS app and OpenAI.
 *
 * Why this exists: an API key shipped inside an iOS binary can be extracted in
 * minutes, so the key lives here as a Cloudflare secret and never touches the
 * device. The app authenticates with a separate app token that can be rotated
 * without publishing a new build.
 *
 * Endpoints
 *   GET  /health   → liveness probe, no auth
 *   POST /analyze  → { image, mimeType, mealName?, answers? } → FoodAnalysis JSON
 *
 * Secrets / vars (see README.md)
 *   OPENAI_API_KEY   secret, required
 *   APP_TOKEN        secret, required — shared with the app
 *   OPENAI_MODEL     var,    optional — defaults to gpt-5-nano
 *   DAILY_LIMIT      var,    optional — analyses per device per day
 *   RATE_LIMIT       KV,     optional — binding that enforces DAILY_LIMIT
 */

const DEFAULT_MODEL = "gpt-5-nano";
const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

// Largest base64 payload we will forward. A 768px JPEG lands around 150 KB of
// base64; 6 MB is generous headroom while still rejecting junk outright.
const MAX_IMAGE_BASE64_BYTES = 6 * 1024 * 1024;

// ---------------------------------------------------------------------------
// Response schema
// ---------------------------------------------------------------------------
// OpenAI strict structured outputs require every property to appear in
// `required` and every object to set `additionalProperties: false`. Fields the
// model has nothing to say about are returned empty rather than omitted.

const FOOD_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["recognized", "dishName", "confidence", "summary", "items", "questions", "notes"],
  properties: {
    recognized: {
      type: "boolean",
      description: "True if the photo contains identifiable food or drink.",
    },
    dishName: {
      type: "string",
      description:
        "Short display name for the whole plate, e.g. 'Papaya' or 'Chicken biryani with raita'. Empty when nothing was recognized.",
    },
    confidence: {
      type: "number",
      description: "How sure you are of the identification, from 0.0 to 1.0.",
    },
    summary: {
      type: "string",
      description: "One friendly sentence describing what you can see. Empty when nothing was recognized.",
    },
    items: {
      type: "array",
      description:
        "One entry per distinct food or drink on the plate. Nutrition values are for the portion visible in the photo.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "portion", "calories", "protein", "carbs", "fat", "fiber", "iron"],
        properties: {
          name: { type: "string", description: "Food name, title case, e.g. 'Papaya'." },
          portion: {
            type: "string",
            description: "Human-readable portion actually visible, e.g. '1 cup cubed' or '2 medium chappathi'.",
          },
          calories: { type: "integer", description: "Kilocalories for this portion." },
          protein: { type: "number", description: "Grams of protein." },
          carbs: { type: "number", description: "Grams of carbohydrate." },
          fat: { type: "number", description: "Grams of fat." },
          fiber: { type: "number", description: "Grams of dietary fibre." },
          iron: { type: "number", description: "Milligrams of iron." },
        },
      },
    },
    questions: {
      type: "array",
      description:
        "Ask only when the answer would meaningfully change the calorie total and the photo genuinely cannot settle it — portion size, cooking method, whether sugar or oil was added. Never more than 2. Return an empty array when the photo is clear enough.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "prompt", "allowCustom", "options"],
        properties: {
          id: { type: "string", description: "Stable slug such as 'portion' or 'cooking_method'." },
          prompt: { type: "string", description: "The question, addressed to the user in plain language." },
          allowCustom: {
            type: "boolean",
            description: "True when a free-text answer makes sense in addition to the options.",
          },
          options: {
            type: "array",
            description: "Between 2 and 5 choices, ordered smallest to largest where that applies.",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["label", "detail"],
              properties: {
                label: { type: "string", description: "Short choice, e.g. 'Half a fruit'." },
                detail: {
                  type: "string",
                  description: "Optional hint shown under the label, e.g. '~60 cal'. Empty string if not useful.",
                },
              },
            },
          },
        },
      },
    },
    notes: {
      type: "string",
      description: "Optional caveat worth showing the user, e.g. 'Dressing is hard to judge from the photo.' Empty if none.",
    },
  },
};

const SYSTEM_PROMPT = `You are a nutrition analyst for a personal daily-planner app. The user photographs a meal and you identify it and estimate its nutrition.

Your job:
1. Identify every distinct food and drink in the photo. Split a mixed plate into its components — rice, dal, papad and pickle are four items, not one.
2. Estimate the portion actually visible, using everyday units the user would recognise (1 cup, 2 medium, 1 small bowl, 150 g). Judge scale from plates, cutlery, hands and packaging in frame.
3. Give calories and macros for that portion. Round calories to the nearest 5.
4. Be decisive. If it is plainly a papaya, say papaya with high confidence — do not hedge into "fruit".

You are strong on Indian, Mediterranean, Middle Eastern and Western home cooking. Use the local name the user would use (chappathi, appalam, dosa, sambar, hummus, tabbouleh) rather than a generic translation.

Ask a question only when it genuinely changes the number and the photo cannot settle it — a bowl whose depth you cannot see, whether a juice has added sugar, whether something was fried or grilled. At most two questions, each with 2 to 5 concrete options. When the photo is clear, return an empty questions array and let the user just save it.

If the photo has no food in it, set recognized to false, leave dishName and items empty, and say what you see in summary.

Nutrition figures are honest estimates from visual inspection, not laboratory values. Never refuse; give your best estimate.`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const fail = (code, message, status) => json({ error: { code, message } }, status);

/**
 * Constant-time-ish string compare so a wrong app token cannot be recovered by
 * timing the response. Length is allowed to leak; the value is not.
 */
function tokensMatch(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Per-device daily cap, enforced only when a RATE_LIMIT KV namespace is bound.
 * Returns null when the request is allowed, or a Response when it is not.
 */
async function enforceRateLimit(env, deviceID) {
  if (!env.RATE_LIMIT || !deviceID) return null;

  const limit = Number(env.DAILY_LIMIT || 0);
  if (!Number.isFinite(limit) || limit <= 0) return null;

  const day = new Date().toISOString().slice(0, 10); // UTC day bucket
  const key = `d:${day}:${deviceID}`;
  const used = Number((await env.RATE_LIMIT.get(key)) || 0);

  if (used >= limit) {
    return fail(
      "daily_limit_reached",
      `You've used all ${limit} photo analyses for today. They reset tomorrow.`,
      429
    );
  }

  // 48h TTL comfortably outlives the UTC day bucket in every timezone.
  await env.RATE_LIMIT.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
  return null;
}

/** Builds the user turn: the photo, plus any answers from the first round. */
function buildUserContent({ image, mimeType, mealName, answers, note }) {
  const lines = [];
  lines.push(mealName ? `This is the user's ${mealName}.` : "Analyse this meal photo.");

  if (Array.isArray(answers) && answers.length > 0) {
    lines.push("", "The user has answered your follow-up questions:");
    for (const a of answers) {
      if (a && a.prompt && a.answer) lines.push(`- ${a.prompt} → ${a.answer}`);
    }
    lines.push(
      "",
      "Use these answers to finalise the numbers. Return an empty questions array — do not ask anything further."
    );
  }

  if (note && String(note).trim()) {
    lines.push("", `The user adds: ${String(note).trim()}`);
  }

  return [
    { type: "text", text: lines.join("\n") },
    {
      type: "image_url",
      image_url: { url: `data:${mimeType};base64,${image}`, detail: "auto" },
    },
  ];
}

/**
 * Normalises the model's output so the Swift client can decode it without
 * defensive optionals everywhere. A malformed field becomes a sane default
 * rather than a decode failure on the device.
 */
function normalize(raw) {
  const num = (v) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
  const str = (v) => (typeof v === "string" ? v : "");

  const items = Array.isArray(raw.items)
    ? raw.items
        .filter((i) => i && str(i.name).trim())
        .map((i) => ({
          name: str(i.name).trim(),
          portion: str(i.portion).trim(),
          calories: Math.max(0, Math.round(num(i.calories))),
          protein: Math.max(0, Math.round(num(i.protein) * 10) / 10),
          carbs: Math.max(0, Math.round(num(i.carbs) * 10) / 10),
          fat: Math.max(0, Math.round(num(i.fat) * 10) / 10),
          fiber: Math.max(0, Math.round(num(i.fiber) * 10) / 10),
          iron: Math.max(0, Math.round(num(i.iron) * 100) / 100),
        }))
    : [];

  // Drop unusable questions BEFORE capping at two, so a malformed first
  // question doesn't cost the user a good second one.
  const questions = Array.isArray(raw.questions)
    ? raw.questions
        .filter(
          (q) =>
            q &&
            str(q.prompt).trim() &&
            Array.isArray(q.options) &&
            q.options.some((o) => o && str(o.label).trim())
        )
        .slice(0, 2)
        .map((q, qi) => ({
          id: str(q.id).trim() || `q${qi}`,
          prompt: str(q.prompt).trim(),
          allowCustom: q.allowCustom !== false,
          options: q.options
            .filter((o) => o && str(o.label).trim())
            .slice(0, 5)
            .map((o) => ({ label: str(o.label).trim(), detail: str(o.detail).trim() })),
        }))
        .filter((q) => q.options.length > 0)
    : [];

  const confidence = Math.min(1, Math.max(0, num(raw.confidence)));

  return {
    recognized: raw.recognized === true && items.length > 0,
    dishName: str(raw.dishName).trim(),
    confidence,
    summary: str(raw.summary).trim(),
    items,
    questions,
    notes: str(raw.notes).trim(),
  };
}

// ---------------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------------

async function handleAnalyze(request, env) {
  if (!env.OPENAI_API_KEY) {
    return fail("not_configured", "The analysis service is not configured yet.", 500);
  }
  if (!env.APP_TOKEN) {
    return fail("not_configured", "The analysis service is not configured yet.", 500);
  }

  if (!tokensMatch(request.headers.get("x-app-token") || "", env.APP_TOKEN)) {
    return fail("unauthorized", "This app build is not allowed to use the analysis service.", 401);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return fail("bad_request", "Could not read the request.", 400);
  }

  const image = typeof body.image === "string" ? body.image : "";
  if (!image) return fail("bad_request", "No photo was sent.", 400);
  if (image.length > MAX_IMAGE_BASE64_BYTES) {
    return fail("image_too_large", "That photo is too large — try again.", 413);
  }

  const mimeType = /^image\/(jpeg|png|webp|gif)$/.test(body.mimeType || "")
    ? body.mimeType
    : "image/jpeg";

  const limited = await enforceRateLimit(env, typeof body.deviceID === "string" ? body.deviceID : "");
  if (limited) return limited;

  const payload = {
    model: env.OPENAI_MODEL || DEFAULT_MODEL,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      {
        role: "user",
        content: buildUserContent({
          image,
          mimeType,
          mealName: typeof body.mealName === "string" ? body.mealName : "",
          answers: body.answers,
          note: body.note,
        }),
      },
    ],
    response_format: {
      type: "json_schema",
      json_schema: { name: "food_analysis", strict: true, schema: FOOD_SCHEMA },
    },
    // GPT-5 family: reasoning tokens count against this, so leave headroom.
    // `temperature` is deliberately absent — these models only accept the default.
    max_completion_tokens: 3000,
    reasoning_effort: "low",
  };

  let upstream;
  try {
    upstream = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch {
    return fail("upstream_unreachable", "Couldn't reach the analysis service. Check your connection.", 502);
  }

  if (!upstream.ok) {
    const detail = await upstream.text().catch(() => "");
    // Log the real reason for the operator; the device gets a friendly line.
    console.error("openai error", upstream.status, detail.slice(0, 800));

    if (upstream.status === 429) {
      return fail("busy", "The analysis service is busy right now. Try again in a moment.", 429);
    }
    return fail("upstream_error", "Couldn't analyse that photo. Please try again.", 502);
  }

  const completion = await upstream.json().catch(() => null);
  const choice = completion && completion.choices && completion.choices[0];
  const content = choice && choice.message && choice.message.content;

  if (!content) {
    // Most often this is `finish_reason: "length"` — reasoning ate the budget.
    console.error("empty completion", JSON.stringify(choice || {}).slice(0, 800));
    return fail("empty_result", "Couldn't read the food in that photo. Try a clearer shot.", 502);
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch {
    console.error("unparseable content", content.slice(0, 800));
    return fail("empty_result", "Couldn't read the food in that photo. Try a clearer shot.", 502);
  }

  const result = normalize(parsed);
  const usage = completion.usage || {};

  return json({
    ...result,
    model: completion.model || payload.model,
    usage: {
      inputTokens: usage.prompt_tokens || 0,
      outputTokens: usage.completion_tokens || 0,
    },
  });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    if (pathname === "/health") {
      return json({
        ok: true,
        configured: Boolean(env.OPENAI_API_KEY && env.APP_TOKEN),
        model: env.OPENAI_MODEL || DEFAULT_MODEL,
      });
    }

    if (pathname === "/analyze") {
      if (request.method !== "POST") return fail("method_not_allowed", "Use POST.", 405);
      return handleAnalyze(request, env);
    }

    return fail("not_found", "Unknown endpoint.", 404);
  },
};
