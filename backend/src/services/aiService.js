require('dotenv').config();
const OpenAI = require('openai');

// OpenRouter is OpenAI-API-compatible, so we reuse the OpenAI SDK
const openrouter = new OpenAI({
  apiKey: process.env.OPENROUTER_API_KEY,
  baseURL: process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1',
  defaultHeaders: {
    'HTTP-Referer': 'https://habitai.app',
    'X-Title': 'HabitAI',
  },
});

// Free models available on OpenRouter
const MODELS = {
  smart: 'openrouter/free',   // auto-routes to best free model
  fast:  'openrouter/free',   // chat, quick tasks
};

async function chat(messages, { model = MODELS.fast, systemPrompt, maxTokens = 400 } = {}) {
  const msgs = systemPrompt
    ? [{ role: 'system', content: systemPrompt }, ...messages]
    : messages;

  const response = await openrouter.chat.completions.create({
    model,
    max_tokens: maxTokens,
    messages: msgs,
  });
  return response.choices[0].message.content;
}

module.exports = { chat, MODELS };
