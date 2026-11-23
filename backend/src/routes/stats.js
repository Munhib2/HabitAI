const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

// GET /api/stats/streaks
router.get('/streaks', authenticate, async (req, res) => {
  const { data: habits } = await supabase
    .from('habits')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('is_archived', false);

  const { data: checkins } = await supabase
    .from('checkins')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('completed', true)
    .order('date', { ascending: false });

  const streaks = habits.map(habit => {
    const habitCheckins = checkins
      .filter(c => c.habit_id === habit.id)
      .map(c => c.date)
      .sort((a, b) => b.localeCompare(a));

    let currentStreak = 0;
    let longestStreak = 0;
    let tempStreak = 0;
    const today = new Date().toISOString().split('T')[0];
    let checkDate = new Date(today);

    // Calculate current streak
    for (let i = 0; ; i++) {
      const dateStr = checkDate.toISOString().split('T')[0];
      if (habitCheckins.includes(dateStr)) {
        currentStreak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }

    // Calculate longest streak
    let prevDate = null;
    for (const date of habitCheckins) {
      if (!prevDate) {
        tempStreak = 1;
      } else {
        const diff = (new Date(prevDate) - new Date(date)) / (1000 * 60 * 60 * 24);
        tempStreak = diff === 1 ? tempStreak + 1 : 1;
      }
      longestStreak = Math.max(longestStreak, tempStreak);
      prevDate = date;
    }

    const totalDays = Math.max(1, Math.ceil((new Date() - new Date(habit.created_at)) / (1000 * 60 * 60 * 24)));
    const completionRate = Math.round((habitCheckins.length / totalDays) * 100);

    return {
      habit_id: habit.id,
      habit_name: habit.name,
      habit_color: habit.color,
      habit_icon: habit.icon,
      current_streak: currentStreak,
      longest_streak: longestStreak,
      completion_rate: completionRate,
      total_completions: habitCheckins.length,
    };
  });

  res.json(streaks);
});

// GET /api/stats/overview
router.get('/overview', authenticate, async (req, res) => {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const dateStr = thirtyDaysAgo.toISOString().split('T')[0];

  const [habitsResult, checkinsResult] = await Promise.all([
    supabase.from('habits').select('id, name, color').eq('user_id', req.user.id).eq('is_archived', false),
    supabase.from('checkins').select('*').eq('user_id', req.user.id).gte('date', dateStr).order('date'),
  ]);

  const habits = habitsResult.data || [];
  const checkins = checkinsResult.data || [];

  const totalCheckins = checkins.filter(c => c.completed).length;
  const possibleCheckins = habits.length * 30;
  const overallRate = possibleCheckins > 0 ? Math.round((totalCheckins / possibleCheckins) * 100) : 0;

  // Group by date for heatmap
  const heatmap = {};
  checkins.forEach(c => {
    if (!heatmap[c.date]) heatmap[c.date] = { total: 0, completed: 0 };
    heatmap[c.date].total++;
    if (c.completed) heatmap[c.date].completed++;
  });

  res.json({
    total_habits: habits.length,
    overall_completion_rate: overallRate,
    total_completions_30d: totalCheckins,
    heatmap,
    habits_summary: habits.map(h => ({
      id: h.id,
      name: h.name,
      color: h.color,
      completions: checkins.filter(c => c.habit_id === h.id && c.completed).length,
    })),
  });
});

module.exports = router;
