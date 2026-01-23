const https = require('https');
const http = require('http');

const N8N_API_URL = process.env.N8N_API_URL || 'https://ulucky.app.n8n.cloud';
const N8N_API_KEY = process.env.N8N_API_KEY;

if (!N8N_API_KEY) {
  console.warn('Warning: N8N_API_KEY is not set');
}

/**
 * Make an API request to n8n
 * @param {string} method - HTTP method
 * @param {string} endpoint - API endpoint
 * @param {object} data - Request body (for POST/PUT/PATCH)
 */
async function request(method, endpoint, data = null) {
  const url = new URL(`/api/v1${endpoint}`, N8N_API_URL);
  const isHttps = url.protocol === 'https:';
  const lib = isHttps ? https : http;

  const options = {
    hostname: url.hostname,
    port: url.port || (isHttps ? 443 : 80),
    path: url.pathname + url.search,
    method,
    headers: {
      'X-N8N-API-KEY': N8N_API_KEY,
      'Content-Type': 'application/json'
    }
  };

  return new Promise((resolve, reject) => {
    const req = lib.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(json.message || `HTTP ${res.statusCode}`));
          } else {
            resolve(json);
          }
        } catch (e) {
          reject(new Error(`Invalid JSON response: ${body}`));
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

/**
 * Get all workflows
 * @param {object} options - Query options
 * @param {boolean} options.active - Filter by active status
 * @param {number} options.limit - Limit results
 * @param {string} options.cursor - Pagination cursor
 */
async function getWorkflows(options = {}) {
  let endpoint = '/workflows';
  const params = new URLSearchParams();

  if (options.active !== undefined) params.append('active', options.active);
  if (options.limit) params.append('limit', options.limit);
  if (options.cursor) params.append('cursor', options.cursor);

  const query = params.toString();
  if (query) endpoint += `?${query}`;

  return request('GET', endpoint);
}

/**
 * Get a specific workflow by ID
 * @param {string} workflowId - Workflow ID
 */
async function getWorkflow(workflowId) {
  return request('GET', `/workflows/${workflowId}`);
}

/**
 * Activate a workflow
 * @param {string} workflowId - Workflow ID
 */
async function activateWorkflow(workflowId) {
  return request('POST', `/workflows/${workflowId}/activate`);
}

/**
 * Deactivate a workflow
 * @param {string} workflowId - Workflow ID
 */
async function deactivateWorkflow(workflowId) {
  return request('POST', `/workflows/${workflowId}/deactivate`);
}

/**
 * Get all executions
 * @param {object} options - Query options
 */
async function getExecutions(options = {}) {
  let endpoint = '/executions';
  const params = new URLSearchParams();

  if (options.workflowId) params.append('workflowId', options.workflowId);
  if (options.status) params.append('status', options.status);
  if (options.limit) params.append('limit', options.limit);

  const query = params.toString();
  if (query) endpoint += `?${query}`;

  return request('GET', endpoint);
}

/**
 * Get a specific execution
 * @param {string} executionId - Execution ID
 */
async function getExecution(executionId) {
  return request('GET', `/executions/${executionId}`);
}

module.exports = {
  request,
  getWorkflows,
  getWorkflow,
  activateWorkflow,
  deactivateWorkflow,
  getExecutions,
  getExecution,
  N8N_API_URL
};
