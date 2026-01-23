const { supabase, supabaseAdmin } = require('./client');

/**
 * Sign up with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 * @param {object} options - Additional options
 * @param {object} options.data - User metadata
 */
async function signUp(email, password, options = {}) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: options.data
    }
  });
  if (error) throw error;
  return data;
}

/**
 * Sign in with email and password
 * @param {string} email - User email
 * @param {string} password - User password
 */
async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  if (error) throw error;
  return data;
}

/**
 * Sign in with OAuth provider
 * @param {string} provider - OAuth provider (google, github, etc.)
 * @param {object} options - OAuth options
 */
async function signInWithOAuth(provider, options = {}) {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider,
    options
  });
  if (error) throw error;
  return data;
}

/**
 * Sign in with magic link (passwordless)
 * @param {string} email - User email
 * @param {object} options - Magic link options
 */
async function signInWithMagicLink(email, options = {}) {
  const { data, error } = await supabase.auth.signInWithOtp({
    email,
    options
  });
  if (error) throw error;
  return data;
}

/**
 * Sign out current user
 */
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
  return { success: true };
}

/**
 * Get current session
 */
async function getSession() {
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  return data.session;
}

/**
 * Get current user
 */
async function getUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) throw error;
  return data.user;
}

/**
 * Update user data
 * @param {object} updates - User updates (email, password, data)
 */
async function updateUser(updates) {
  const { data, error } = await supabase.auth.updateUser(updates);
  if (error) throw error;
  return data;
}

/**
 * Reset password (send reset email)
 * @param {string} email - User email
 * @param {object} options - Reset options
 */
async function resetPassword(email, options = {}) {
  const { data, error } = await supabase.auth.resetPasswordForEmail(email, options);
  if (error) throw error;
  return data;
}

/**
 * Refresh session
 */
async function refreshSession() {
  const { data, error } = await supabase.auth.refreshSession();
  if (error) throw error;
  return data;
}

/**
 * Listen to auth state changes
 * @param {function} callback - Callback function (event, session)
 */
function onAuthStateChange(callback) {
  return supabase.auth.onAuthStateChange(callback);
}

// Admin functions (require service key)

/**
 * Get user by ID (admin)
 * @param {string} userId - User ID
 */
async function adminGetUser(userId) {
  if (!supabaseAdmin) throw new Error('Admin client not available');
  const { data, error } = await supabaseAdmin.auth.admin.getUserById(userId);
  if (error) throw error;
  return data.user;
}

/**
 * List all users (admin)
 * @param {object} options - List options
 */
async function adminListUsers(options = {}) {
  if (!supabaseAdmin) throw new Error('Admin client not available');
  const { data, error } = await supabaseAdmin.auth.admin.listUsers(options);
  if (error) throw error;
  return data;
}

/**
 * Create user (admin)
 * @param {object} userData - User data
 */
async function adminCreateUser(userData) {
  if (!supabaseAdmin) throw new Error('Admin client not available');
  const { data, error } = await supabaseAdmin.auth.admin.createUser(userData);
  if (error) throw error;
  return data.user;
}

/**
 * Delete user (admin)
 * @param {string} userId - User ID
 */
async function adminDeleteUser(userId) {
  if (!supabaseAdmin) throw new Error('Admin client not available');
  const { data, error } = await supabaseAdmin.auth.admin.deleteUser(userId);
  if (error) throw error;
  return data;
}

module.exports = {
  signUp,
  signIn,
  signInWithOAuth,
  signInWithMagicLink,
  signOut,
  getSession,
  getUser,
  updateUser,
  resetPassword,
  refreshSession,
  onAuthStateChange,
  adminGetUser,
  adminListUsers,
  adminCreateUser,
  adminDeleteUser
};
