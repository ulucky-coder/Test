const { supabase } = require('./client');

/**
 * Subscribe to database changes on a table
 * @param {string} table - Table name
 * @param {object} options - Subscription options
 * @param {string} options.event - Event type: INSERT, UPDATE, DELETE, or * for all
 * @param {string} options.schema - Schema name (default: public)
 * @param {string} options.filter - Filter expression (e.g., 'user_id=eq.123')
 * @param {function} callback - Callback function (payload)
 * @returns {object} - Channel subscription
 */
function subscribeToTable(table, options = {}, callback) {
  const event = options.event || '*';
  const schema = options.schema || 'public';

  const channelConfig = {
    event,
    schema,
    table
  };

  if (options.filter) {
    channelConfig.filter = options.filter;
  }

  const channel = supabase
    .channel(`${table}-changes`)
    .on('postgres_changes', channelConfig, callback)
    .subscribe();

  return channel;
}

/**
 * Subscribe to INSERT events on a table
 * @param {string} table - Table name
 * @param {function} callback - Callback function
 * @param {object} options - Additional options
 */
function onInsert(table, callback, options = {}) {
  return subscribeToTable(table, { ...options, event: 'INSERT' }, callback);
}

/**
 * Subscribe to UPDATE events on a table
 * @param {string} table - Table name
 * @param {function} callback - Callback function
 * @param {object} options - Additional options
 */
function onUpdate(table, callback, options = {}) {
  return subscribeToTable(table, { ...options, event: 'UPDATE' }, callback);
}

/**
 * Subscribe to DELETE events on a table
 * @param {string} table - Table name
 * @param {function} callback - Callback function
 * @param {object} options - Additional options
 */
function onDelete(table, callback, options = {}) {
  return subscribeToTable(table, { ...options, event: 'DELETE' }, callback);
}

/**
 * Create a broadcast channel for real-time messaging
 * @param {string} channelName - Channel name
 * @param {object} handlers - Event handlers { eventName: callback }
 */
function createBroadcastChannel(channelName, handlers = {}) {
  let channel = supabase.channel(channelName);

  for (const [event, callback] of Object.entries(handlers)) {
    channel = channel.on('broadcast', { event }, callback);
  }

  channel.subscribe();
  return channel;
}

/**
 * Send a broadcast message
 * @param {object} channel - Channel object
 * @param {string} event - Event name
 * @param {object} payload - Message payload
 */
async function broadcast(channel, event, payload) {
  return channel.send({
    type: 'broadcast',
    event,
    payload
  });
}

/**
 * Create a presence channel for tracking online users
 * @param {string} channelName - Channel name
 * @param {object} options - Presence options
 * @param {function} options.onSync - Called when presence state syncs
 * @param {function} options.onJoin - Called when user joins
 * @param {function} options.onLeave - Called when user leaves
 */
function createPresenceChannel(channelName, options = {}) {
  const channel = supabase.channel(channelName);

  if (options.onSync) {
    channel.on('presence', { event: 'sync' }, () => {
      const state = channel.presenceState();
      options.onSync(state);
    });
  }

  if (options.onJoin) {
    channel.on('presence', { event: 'join' }, ({ key, newPresences }) => {
      options.onJoin(key, newPresences);
    });
  }

  if (options.onLeave) {
    channel.on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
      options.onLeave(key, leftPresences);
    });
  }

  channel.subscribe();
  return channel;
}

/**
 * Track presence (mark user as online)
 * @param {object} channel - Presence channel
 * @param {object} userState - User state to track
 */
async function trackPresence(channel, userState) {
  return channel.track(userState);
}

/**
 * Untrack presence (mark user as offline)
 * @param {object} channel - Presence channel
 */
async function untrackPresence(channel) {
  return channel.untrack();
}

/**
 * Unsubscribe from a channel
 * @param {object} channel - Channel to unsubscribe
 */
async function unsubscribe(channel) {
  return supabase.removeChannel(channel);
}

/**
 * Unsubscribe from all channels
 */
async function unsubscribeAll() {
  return supabase.removeAllChannels();
}

module.exports = {
  subscribeToTable,
  onInsert,
  onUpdate,
  onDelete,
  createBroadcastChannel,
  broadcast,
  createPresenceChannel,
  trackPresence,
  untrackPresence,
  unsubscribe,
  unsubscribeAll
};
