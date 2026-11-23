const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

const FREE_HABIT_LIMIT = 3;

// GET /api/habits
router.get('/', authenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('habits')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('is_archived', false)
    .order('created_at', { ascending: true });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
});

// POST /api/habits
router.post('/',
  authenticate,
  [
    body('name').trim().notEmpty().isLength({ max: 100 }),
    body('frequency').isIn(['daily', 'weekly', 'custom']),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    // Enforce free tier limit
    if (req.user.subscription_tier === 'free') {
      const { count } = await supabase
        .from('habits')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', req.user.id)
        .eq('is_archived', false);

      if (count >= FREE_HABIT_LIMIT) {
        return res.status(403).json({ error: 'Free plan limit reached', upgrade_required: true });
      }
    }

    const { name, description, frequency, custom_days, reminder_time, color, icon } = req.body;
    const { data, error } = await supabase
      .from('habits')
      .insert({
        user_id: req.user.id,
        name,
        description: description || null,
        frequency: frequency || 'daily',
        custom_days: custom_days || null,
        reminder_time: reminder_time || null,
        color: color || '#6366F1',
        icon: icon || 'star.fill',
        is_archived: false,
      })
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });
    res.status(201).json(data);
  }
);

// PATCH /api/habits/:id
router.patch('/:id', authenticate, async (req, res) => {
  const { name, description, frequency, custom_days, reminder_time, color, icon } = req.body;
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (description !== undefined) updates.description = description;
  if (frequency !== undefined) updates.frequency = frequency;
  if (custom_days !== undefined) updates.custom_days = custom_days;
  if (reminder_time !== undefined) updates.reminder_time = reminder_time;
  if (color !== undefined) updates.color = color;
  if (icon !== undefined) updates.icon = icon;
  updates.updated_at = new Date().toISOString();

  const { data, error } = await supabase
    .from('habits')
    .update(updates)
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Habit not found' });
  res.json(data);
});

// DELETE /api/habits/:id (archives instead of hard delete)
router.delete('/:id', authenticate, async (req, res) => {
  const { error } = await supabase
    .from('habits')
    .update({ is_archived: true, updated_at: new Date().toISOString() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(400).json({ error: error.message });
  res.json({ success: true });
});

module.exports = router;
