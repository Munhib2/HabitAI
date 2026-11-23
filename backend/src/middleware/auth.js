const jwt = require('jsonwebtoken');
const supabase = require('../services/supabase');

const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', decoded.userId)
      .single();

    if (error || !user) return res.status(401).json({ error: 'User not found' });

    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

const requirePremium = (req, res, next) => {
  if (req.user.subscription_tier !== 'premium') {
    return res.status(403).json({ error: 'Premium subscription required', upgrade_required: true });
  }
  next();
};

module.exports = { authenticate, requirePremium };
