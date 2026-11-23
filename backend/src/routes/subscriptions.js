const express = require('express');
const router = express.Router();
const supabase = require('../services/supabase');
const { authenticate } = require('../middleware/auth');

// POST /api/subscriptions/verify
// Called after StoreKit purchase to verify and activate on server
router.post('/verify', authenticate, async (req, res) => {
  const { transaction_id, product_id, original_transaction_id } = req.body;
  if (!transaction_id || !product_id) {
    return res.status(400).json({ error: 'transaction_id and product_id required' });
  }

  try {
    // Determine tier from product ID
    const premiumProductIds = [
      'com.yourname.habitai.premium.monthly',
      'com.yourname.habitai.premium.yearly',
      'com.yourname.habitai.premium.lifetime',
    ];

    const tier = premiumProductIds.includes(product_id) ? 'premium' : 'free';

    // Record the subscription
    await supabase.from('subscriptions').upsert({
      user_id: req.user.id,
      product_id,
      transaction_id,
      original_transaction_id: original_transaction_id || transaction_id,
      status: 'active',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'original_transaction_id' });

    // Update user tier
    const { data: user, error } = await supabase
      .from('users')
      .update({ subscription_tier: tier, updated_at: new Date().toISOString() })
      .eq('id', req.user.id)
      .select('id, subscription_tier')
      .single();

    if (error) throw error;
    res.json({ success: true, subscription_tier: user.subscription_tier });
  } catch (err) {
    console.error('Subscription verify error:', err);
    res.status(500).json({ error: 'Failed to verify subscription' });
  }
});

// GET /api/subscriptions/status
router.get('/status', authenticate, async (req, res) => {
  const { data: subscription } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('status', 'active')
    .order('updated_at', { ascending: false })
    .limit(1)
    .single();

  res.json({
    subscription_tier: req.user.subscription_tier,
    subscription: subscription || null,
  });
});

// POST /api/subscriptions/restore (App Store restore)
router.post('/restore', authenticate, async (req, res) => {
  const { transactions } = req.body;
  if (!transactions?.length) return res.status(400).json({ error: 'transactions required' });

  const premiumProductIds = [
    'com.yourname.habitai.premium.monthly',
    'com.yourname.habitai.premium.yearly',
    'com.yourname.habitai.premium.lifetime',
  ];

  const hasPremium = transactions.some(t => premiumProductIds.includes(t.productId));

  if (hasPremium) {
    await supabase
      .from('users')
      .update({ subscription_tier: 'premium' })
      .eq('id', req.user.id);
  }

  res.json({ subscription_tier: hasPremium ? 'premium' : 'free', restored: hasPremium });
});

module.exports = router;
