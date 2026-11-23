const cron = require('node-cron');
const { generateCoachingSummary } = require('../routes/coaching');
const supabase = require('./supabase');

function startCronJobs() {
  // Every Sunday at 8 AM — generate weekly coaching summaries for premium users
  cron.schedule('0 8 * * 0', async () => {
    console.log('Running weekly coaching summary job...');
    try {
      const { data: premiumUsers } = await supabase
        .from('users').select('id').eq('subscription_tier', 'premium');

      for (const user of premiumUsers || []) {
        try {
          const content = await generateCoachingSummary(user.id);
          await supabase.from('ai_coaching_logs').insert({
            user_id: user.id, type: 'weekly_summary', content,
          });
        } catch (err) {
          console.error(`Coaching summary failed for user ${user.id}:`, err.message);
        }
      }
      console.log(`Coaching summaries generated for ${premiumUsers?.length || 0} users`);
    } catch (err) {
      console.error('Cron job error:', err);
    }
  });

  console.log('Cron jobs started');
}

module.exports = { startCronJobs };
