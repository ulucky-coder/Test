const { supabase, supabaseAdmin, supabaseUrl } = require('./client');
const data = require('./data');
const auth = require('./auth');
const realtime = require('./realtime');
const storage = require('./storage');

module.exports = {
  // Client instances
  supabase,
  supabaseAdmin,
  supabaseUrl,

  // Data operations
  data,
  read: data.read,
  insert: data.insert,
  update: data.update,
  remove: data.remove,
  rpc: data.rpc,

  // Auth operations
  auth,

  // Realtime operations
  realtime,

  // Storage operations
  storage
};
