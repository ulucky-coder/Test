#!/usr/bin/env node

const { getWorkflows, N8N_API_URL } = require('../src/n8n');

async function main() {
  console.log(`Fetching workflows from ${N8N_API_URL}...\n`);

  try {
    const result = await getWorkflows();
    const workflows = result.data || result;

    if (!workflows || workflows.length === 0) {
      console.log('No workflows found.');
      return;
    }

    console.log(`Found ${workflows.length} workflow(s):\n`);
    console.log('─'.repeat(80));

    workflows.forEach((wf, index) => {
      const status = wf.active ? '✅ Active' : '⏸️  Inactive';
      console.log(`${index + 1}. ${wf.name}`);
      console.log(`   ID: ${wf.id}`);
      console.log(`   Status: ${status}`);
      console.log(`   Created: ${wf.createdAt}`);
      console.log(`   Updated: ${wf.updatedAt}`);
      if (wf.nodes) {
        console.log(`   Nodes: ${wf.nodes.length}`);
      }
      console.log('─'.repeat(80));
    });

  } catch (error) {
    console.error('Error fetching workflows:', error.message);
    process.exit(1);
  }
}

main();
