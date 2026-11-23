const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { chat } = require('../services/aiService');
const { authenticate, requirePremium } = require('../middleware/auth');

// POST /api/voice/parse
// Receives the transcript text (already transcribed on-device by Apple Speech)
// Uses OpenRouter to parse which habits were completed
router.post('/parse', authenticate, requirePremium, async (req, res) => {
  const { transcript } = req.body;
  if (!transcript) return res.status(400).json({ error: 'transcript required' });

  try {
    const { data: habits } = await supabase
      .from('habits').select('id, name')
      .eq('user_id', req.user.id).eq('is_archived', false);

    const reply = await chat([{
      role: 'user',
      content: `The user said: "${transcript}"

Their habits are: ${habits.map(h => `${h.id}: ${h.name}`).join(', ')}

Parse which habits were completed (true) or skipped (false). Extract any personal note.
Respond ONLY with valid JSON (no markdown, no explanation):
{"completions":[{"habit_id":"uuid","completed":true}],"note":"any note or null"}
Only include habits explicitly mentioned.`
    }], { maxTokens: 300 });

    let parsed = { completions: [], note: transcript };
    try {
      const jsonMatch = reply.match(/\{[\s\S]*\}/);
      if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
    } catch { /* keep defaults */ }

    // Auto-log the parsed check-ins
    const today = new Date().toISOString().split('T')[0];
    await Promise.all(parsed.completions.map(c =>
      supabase.from('checkins').upsert(
        { habit_id: c.habit_id, user_id: req.user.id, date: today, completed: c.completed, note: parsed.note },
        { onConflict: 'habit_id,date' }
      )
    ));

    res.json({ transcript, parsed, success: true });
  } catch (err) {
    console.error('Voice parse error:', err);
    res.status(500).json({ error: 'Failed to parse voice input' });
  }
});

module.exports = router;
