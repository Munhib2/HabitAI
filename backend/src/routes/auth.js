const express = require('express');
const router = express.Router();
const appleSignin = require('apple-signin-auth');
const jwt = require('jsonwebtoken');
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/auth/apple
router.post('/apple', async (req, res) => {
  try {
    const { identityToken, fullName } = req.body;
    if (!identityToken) return res.status(400).json({ error: 'identityToken required' });

    const appleUser = await appleSignin.verifyIdToken(identityToken, {
      audience: process.env.APPLE_CLIENT_ID,
      ignoreExpiration: false,
    });

    const appleId = appleUser.sub;
    const email = appleUser.email;

    let { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('apple_id', appleId)
      .single();

    if (!user) {
      const displayName = fullName
        ? `${fullName.givenName || ''} ${fullName.familyName || ''}`.trim()
        : 'HabitAI User';

      const { data: newUser, error } = await supabase
        .from('users')
        .insert({
          apple_id: appleId,
          email,
          display_name: displayName,
          subscription_tier: 'free',
          timezone: 'UTC',
        })
        .select()
        .single();

      if (error) throw error;
      user = newUser;
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '90d' });
    res.json({ token, user: { id: user.id, display_name: user.display_name, subscription_tier: user.subscription_tier } });
  } catch (err) {
    console.error('Apple auth error:', err);
    res.status(501).json({ error: 'Apple authentication failed' });
  }
});

// POST /api/auth/demo (Dev / Simulator login without Apple Developer account)
router.post('/demo', async (req, res) => {
  try {
    const demoId = req.body.demo_id || 'demo-user-1';
    let { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('apple_id', demoId)
      .single();

    if (!user) {
      const { data: newUser, error } = await supabase
        .from('users')
        .insert({
          apple_id: demoId,
          display_name: 'Habit Explorer',
          subscription_tier: 'premium',
          timezone: 'UTC',
        })
        .select()
        .single();

      if (error) throw error;
      user = newUser;
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '90d' });
    res.json({ token, user: { id: user.id, display_name: user.display_name, subscription_tier: user.subscription_tier } });
  } catch (err) {
    console.error('Demo auth error:', err);
    res.status(500).json({ error: 'Demo authentication failed' });
  }
});

// GET /api/auth/me
router.get('/me', authenticate, (req, res) => {
  const { id, display_name, email, subscription_tier, timezone, created_at } = req.user;
  res.json({ id, display_name, email, subscription_tier, timezone, created_at });
});

// PATCH /api/auth/me
router.patch('/me', authenticate, async (req, res) => {
  const { display_name, timezone } = req.body;
  const updates = {};
  if (display_name) updates.display_name = display_name;
  if (timezone) updates.timezone = timezone;

  const { data, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', req.user.id)
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
});

// POST /api/auth/device-token (for push notifications)
router.post('/device-token', authenticate, async (req, res) => {
  const { device_token, platform } = req.body;
  if (!device_token) return res.status(400).json({ error: 'device_token required' });

  const { error } = await supabase
    .from('device_tokens')
    .upsert({ user_id: req.user.id, token: device_token, platform: platform || 'ios' }, { onConflict: 'token' });

  if (error) return res.status(400).json({ error: error.message });
  res.json({ success: true });
});

module.exports = router;
