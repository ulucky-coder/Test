const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl) {
  throw new Error('SUPABASE_URL is required');
}

if (!supabaseKey && !supabaseServiceKey) {
  throw new Error('SUPABASE_ANON_KEY or SUPABASE_SERVICE_KEY is required');
}

// Public client (uses anon key, respects RLS)
const supabase = createClient(supabaseUrl, supabaseKey || supabaseServiceKey);

// Admin client (uses service key, bypasses RLS) - use with caution
const supabaseAdmin = supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })
  : null;

module.exports = {
  supabase,
  supabaseAdmin,
  supabaseUrl
};
