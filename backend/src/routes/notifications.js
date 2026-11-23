const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/notifications/check-streaks
// Returns which habits are at risk today (called from iOS to schedule local notifications)
router.post('/check-streaks', authenticate, async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    const { data: habits } = await supabase
      .from('habits').select('id, name')
      .eq('user_id', req.user.id).eq('is_archived', false);

    const { data: todayCheckins } = await supabase
      .from('checkins').select('habit_id')
      .eq('user_id', req.user.id).eq('date', today).eq('completed', true);

    const completedIds = new Set((todayCheckins || []).map(c => c.habit_id));
    const atRisk = (habits || []).filter(h => !completedIds.has(h.id));

    res.json({ at_risk: atRisk, completed_count: completedIds.size, total: habits?.length || 0 });
  } catch (err) {
    console.error('Streak check error:', err);
    res.status(500).json({ error: 'Failed to check streaks' });
  }
});

module.exports = router;
