const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { chat, MODELS } = require('../services/aiService');
const { authenticate, requirePremium } = require('../middleware/auth');

async function generateCoachingSummary(userId) {
  const oneWeekAgo = new Date();
  oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
  const weekStart = oneWeekAgo.toISOString().split('T')[0];

  const [habitsResult, checkinsResult, pastCoachingResult] = await Promise.all([
    supabase.from('habits').select('*').eq('user_id', userId).eq('is_archived', false),
    supabase.from('checkins').select('*, habits(name)').eq('user_id', userId).gte('date', weekStart),
    supabase.from('ai_coaching_logs').select('content').eq('user_id', userId).eq('type', 'weekly_summary')
      .order('generated_at', { ascending: false }).limit(2),
  ]);

  const habits = habitsResult.data || [];
  const checkins = checkinsResult.data || [];

  const habitStats = habits.map(h => {
    const habitCheckins = checkins.filter(c => c.habit_id === h.id);
    const completed = habitCheckins.filter(c => c.completed).length;
    const notes = habitCheckins.filter(c => c.note).map(c => c.note);
    return { name: h.name, completed_days: completed, notes };
  });

  const pastCoaching = (pastCoachingResult.data || []).map(c => c.content).join('\n\n---\n\n');

  const prompt = `You are a supportive habit coach. Analyze this user's week:

HABITS THIS WEEK:
${habitStats.map(h => `- ${h.name}: ${h.completed_days}/7 days${h.notes.length ? ` | Notes: "${h.notes.join(', ')}"` : ''}`).join('\n')}

PREVIOUS COACHING:
${pastCoaching || 'First week — no prior notes.'}

Write a coaching summary (under 180 words):
1. What they did well (be specific)
2. One clear pattern to notice
3. ONE concrete suggestion for next week
4. A warm closing line

Be warm, direct, and skip generic platitudes.`;

  return await chat([{ role: 'user', content: prompt }], { model: MODELS.smart, maxTokens: 400 });
}

// GET /api/coaching/weekly
router.get('/weekly', authenticate, requirePremium, async (req, res) => {
  try {
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
    const { data: cached } = await supabase
      .from('ai_coaching_logs')
      .select('*')
      .eq('user_id', req.user.id)
      .eq('type', 'weekly_summary')
      .gte('generated_at', sixHoursAgo)
      .order('generated_at', { ascending: false })
      .limit(1)
      .single();

    if (cached) return res.json(cached);

    const content = await generateCoachingSummary(req.user.id);
    const { data, error } = await supabase
      .from('ai_coaching_logs')
      .insert({ user_id: req.user.id, type: 'weekly_summary', content })
      .select()
      .single();

    if (error) throw error;
    res.json(data);
  } catch (err) {
    console.error('Coaching error:', err);
    res.status(500).json({ error: 'Failed to generate coaching summary' });
  }
});

// POST /api/coaching/chat
router.post('/chat', authenticate, requirePremium, async (req, res) => {
  const { message, conversation_history = [] } = req.body;
  if (!message) return res.status(400).json({ error: 'message required' });

  try {
    const { data: habits } = await supabase
      .from('habits').select('name').eq('user_id', req.user.id).eq('is_archived', false);

    const systemPrompt = `You are an AI habit coach. The user's habits: ${habits.map(h => h.name).join(', ')}. Be supportive, practical, concise — under 150 words per reply.`;

    const messages = [
      ...conversation_history.slice(-10),
      { role: 'user', content: message },
    ];

    const reply = await chat(messages, { systemPrompt, maxTokens: 300 });

    await supabase.from('ai_coaching_logs').insert({
      user_id: req.user.id,
      type: 'chat',
      content: `User: ${message}\nCoach: ${reply}`,
    });

    res.json({ reply, role: 'assistant' });
  } catch (err) {
    console.error('Chat error:', err);
    res.status(500).json({ error: 'Chat failed' });
  }
});

// GET /api/coaching/insight
router.get('/insight', authenticate, requirePremium, async (req, res) => {
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split('T')[0];

    const { data: checkins } = await supabase
      .from('checkins').select('*, habits(name)')
      .eq('user_id', req.user.id).eq('date', dateStr);

    const completed = checkins?.filter(c => c.completed).map(c => c.habits.name) || [];
    const missed = checkins?.filter(c => !c.completed).map(c => c.habits.name) || [];

    const insight = await chat([{
      role: 'user',
      content: `Yesterday: completed ${completed.join(', ') || 'nothing'}. Missed: ${missed.join(', ') || 'nothing'}. Give one short encouraging insight (max 2 sentences).`
    }], { maxTokens: 80 });

    res.json({ insight });
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate insight' });
  }
});

module.exports = router;
module.exports.generateCoachingSummary = generateCoachingSummary;
