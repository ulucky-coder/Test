const { supabase, supabaseAdmin } = require('./client');

/**
 * Upload a file to storage
 * @param {string} bucket - Bucket name
 * @param {string} path - File path in bucket
 * @param {Buffer|Blob|File} file - File to upload
 * @param {object} options - Upload options
 * @param {string} options.contentType - MIME type
 * @param {boolean} options.upsert - Overwrite if exists
 * @param {boolean} options.useAdmin - Use admin client
 */
async function upload(bucket, path, file, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .upload(path, file, {
      contentType: options.contentType,
      upsert: options.upsert || false
    });

  if (error) throw error;
  return data;
}

/**
 * Download a file from storage
 * @param {string} bucket - Bucket name
 * @param {string} path - File path in bucket
 * @param {object} options - Download options
 */
async function download(bucket, path, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .download(path);

  if (error) throw error;
  return data;
}

/**
 * Get public URL for a file
 * @param {string} bucket - Bucket name
 * @param {string} path - File path in bucket
 * @param {object} options - URL options
 * @param {object} options.transform - Image transformation options
 */
function getPublicUrl(bucket, path, options = {}) {
  const { data } = supabase.storage
    .from(bucket)
    .getPublicUrl(path, {
      transform: options.transform
    });

  return data.publicUrl;
}

/**
 * Create a signed URL for temporary access
 * @param {string} bucket - Bucket name
 * @param {string} path - File path in bucket
 * @param {number} expiresIn - Expiration time in seconds
 * @param {object} options - Signed URL options
 */
async function createSignedUrl(bucket, path, expiresIn = 3600, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .createSignedUrl(path, expiresIn, {
      transform: options.transform
    });

  if (error) throw error;
  return data.signedUrl;
}

/**
 * Create signed URLs for multiple files
 * @param {string} bucket - Bucket name
 * @param {string[]} paths - Array of file paths
 * @param {number} expiresIn - Expiration time in seconds
 */
async function createSignedUrls(bucket, paths, expiresIn = 3600, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .createSignedUrls(paths, expiresIn);

  if (error) throw error;
  return data;
}

/**
 * List files in a bucket/folder
 * @param {string} bucket - Bucket name
 * @param {string} path - Folder path (optional)
 * @param {object} options - List options
 * @param {number} options.limit - Max files to return
 * @param {number} options.offset - Offset for pagination
 * @param {string} options.sortBy - Sort by field
 */
async function list(bucket, path = '', options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .list(path, {
      limit: options.limit || 100,
      offset: options.offset || 0,
      sortBy: options.sortBy ? { column: options.sortBy.column, order: options.sortBy.order || 'asc' } : undefined
    });

  if (error) throw error;
  return data;
}

/**
 * Move/rename a file
 * @param {string} bucket - Bucket name
 * @param {string} fromPath - Current file path
 * @param {string} toPath - New file path
 */
async function move(bucket, fromPath, toPath, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .move(fromPath, toPath);

  if (error) throw error;
  return data;
}

/**
 * Copy a file
 * @param {string} bucket - Bucket name
 * @param {string} fromPath - Source file path
 * @param {string} toPath - Destination file path
 */
async function copy(bucket, fromPath, toPath, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage
    .from(bucket)
    .copy(fromPath, toPath);

  if (error) throw error;
  return data;
}

/**
 * Delete a file
 * @param {string} bucket - Bucket name
 * @param {string|string[]} paths - File path(s) to delete
 */
async function remove(bucket, paths, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;
  const pathArray = Array.isArray(paths) ? paths : [paths];

  const { data, error } = await client.storage
    .from(bucket)
    .remove(pathArray);

  if (error) throw error;
  return data;
}

/**
 * Create a new bucket (admin only)
 * @param {string} bucketName - Bucket name
 * @param {object} options - Bucket options
 * @param {boolean} options.public - Make bucket public
 * @param {number} options.fileSizeLimit - Max file size in bytes
 * @param {string[]} options.allowedMimeTypes - Allowed MIME types
 */
async function createBucket(bucketName, options = {}) {
  if (!supabaseAdmin) throw new Error('Admin client required');

  const { data, error } = await supabaseAdmin.storage.createBucket(bucketName, {
    public: options.public || false,
    fileSizeLimit: options.fileSizeLimit,
    allowedMimeTypes: options.allowedMimeTypes
  });

  if (error) throw error;
  return data;
}

/**
 * Delete a bucket (admin only)
 * @param {string} bucketName - Bucket name
 */
async function deleteBucket(bucketName) {
  if (!supabaseAdmin) throw new Error('Admin client required');

  const { data, error } = await supabaseAdmin.storage.deleteBucket(bucketName);

  if (error) throw error;
  return data;
}

/**
 * List all buckets
 */
async function listBuckets(options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage.listBuckets();

  if (error) throw error;
  return data;
}

/**
 * Get bucket details
 * @param {string} bucketName - Bucket name
 */
async function getBucket(bucketName, options = {}) {
  const client = options.useAdmin && supabaseAdmin ? supabaseAdmin : supabase;

  const { data, error } = await client.storage.getBucket(bucketName);

  if (error) throw error;
  return data;
}

module.exports = {
  upload,
  download,
  getPublicUrl,
  createSignedUrl,
  createSignedUrls,
  list,
  move,
  copy,
  remove,
  createBucket,
  deleteBucket,
  listBuckets,
  getBucket
};
