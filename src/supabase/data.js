const { supabase, supabaseAdmin } = require('./client');

/**
 * Read data from a table
 * @param {string} table - Table name
 * @param {object} options - Query options
 * @param {string} options.select - Columns to select (default: '*')
 * @param {object} options.filters - Filter conditions { column: value } or { column: { op: 'eq', value: x } }
 * @param {object} options.order - Order by { column: 'asc' | 'desc' }
 * @param {number} options.limit - Limit results
 * @param {number} options.offset - Offset for pagination
 * @param {boolean} options.single - Return single row
 * @param {boolean} options.useAdmin - Use admin client (bypass RLS)
 */
async function read(table, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;
  let query = client.from(table).select(options.select || '*');

  // Apply filters
  if (options.filters) {
    for (const [column, condition] of Object.entries(options.filters)) {
      if (typeof condition === 'object' && condition.op) {
        query = query[condition.op](column, condition.value);
      } else {
        query = query.eq(column, condition);
      }
    }
  }

  // Apply ordering
  if (options.order) {
    for (const [column, direction] of Object.entries(options.order)) {
      query = query.order(column, { ascending: direction === 'asc' });
    }
  }

  // Apply pagination
  if (options.limit) {
    query = query.limit(options.limit);
  }
  if (options.offset) {
    query = query.range(options.offset, options.offset + (options.limit || 10) - 1);
  }

  // Single row
  if (options.single) {
    query = query.single();
  }

  const { data, error } = await query;
  if (error) throw error;
  return data;
}

/**
 * Insert data into a table
 * @param {string} table - Table name
 * @param {object|object[]} records - Record(s) to insert
 * @param {object} options - Insert options
 * @param {boolean} options.useAdmin - Use admin client
 * @param {boolean} options.upsert - Upsert mode
 * @param {string} options.onConflict - Conflict column for upsert
 */
async function insert(table, records, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  let query;
  if (options.upsert) {
    query = client.from(table).upsert(records, { onConflict: options.onConflict });
  } else {
    query = client.from(table).insert(records);
  }

  const { data, error } = await query.select();
  if (error) throw error;
  return data;
}

/**
 * Update data in a table
 * @param {string} table - Table name
 * @param {object} updates - Fields to update
 * @param {object} filters - Filter conditions
 * @param {object} options - Update options
 */
async function update(table, updates, filters, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;
  let query = client.from(table).update(updates);

  for (const [column, value] of Object.entries(filters)) {
    query = query.eq(column, value);
  }

  const { data, error } = await query.select();
  if (error) throw error;
  return data;
}

/**
 * Delete data from a table
 * @param {string} table - Table name
 * @param {object} filters - Filter conditions
 * @param {object} options - Delete options
 */
async function remove(table, filters, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;
  let query = client.from(table).delete();

  for (const [column, value] of Object.entries(filters)) {
    query = query.eq(column, value);
  }

  const { data, error } = await query.select();
  if (error) throw error;
  return data;
}

/**
 * Execute a stored procedure (RPC)
 * @param {string} functionName - Function name
 * @param {object} params - Function parameters
 * @param {object} options - RPC options
 */
async function rpc(functionName, params = {}, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;
  const { data, error } = await client.rpc(functionName, params);
  if (error) throw error;
  return data;
}

module.exports = {
  read,
  insert,
  update,
  remove,
  rpc
};
