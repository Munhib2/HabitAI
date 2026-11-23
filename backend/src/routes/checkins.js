const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/checkins
router.post('/', authenticate, async (req, res) => {
  const { habit_id, date, completed, note, mood } = req.body;
  if (!habit_id || !date) return res.status(400).json({ error: 'habit_id and date required' });

  // Verify habit belongs to user
  const { data: habit } = await supabase
    .from('habits')
    .select('id')
    .eq('id', habit_id)
    .eq('user_id', req.user.id)
    .single();

  if (!habit) return res.status(404).json({ error: 'Habit not found' });

  // Upsert — one check-in per habit per day
  const { data, error } = await supabase
    .from('checkins')
    .upsert(
      {
        habit_id,
        user_id: req.user.id,
        date,
        completed: completed !== undefined ? completed : true,
        note: note || null,
        mood: mood || null,
      },
      { onConflict: 'habit_id,date' }
    )
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
});

// GET /api/checkins?range=week | month | all  &habit_id=optional
router.get('/', authenticate, async (req, res) => {
  const { range = 'week', habit_id } = req.query;

  let startDate = new Date();
  if (range === 'week') startDate.setDate(startDate.getDate() - 7);
  else if (range === 'month') startDate.setDate(startDate.getDate() - 30);
  else if (range === 'all') startDate = new Date('2020-01-01');

  const dateStr = startDate.toISOString().split('T')[0];

  let query = supabase
    .from('checkins')
    .select('*, habits(name, color, icon)')
    .eq('user_id', req.user.id)
    .gte('date', dateStr)
    .order('date', { ascending: false });

  if (habit_id) query = query.eq('habit_id', habit_id);

  const { data, error } = await query;
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
});

// GET /api/checkins/today
router.get('/today', authenticate, async (req, res) => {
  const today = new Date().toISOString().split('T')[0];

  const { data: habits } = await supabase
    .from('habits')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('is_archived', false);

  const { data: checkins } = await supabase
    .from('checkins')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('date', today);

  // Merge habits with their check-in status for today
  const todayData = habits.map(habit => ({
    ...habit,
    checkin: checkins.find(c => c.habit_id === habit.id) || null,
    completed_today: checkins.some(c => c.habit_id === habit.id && c.completed),
  }));

  res.json(todayData);
});

module.exports = router;
