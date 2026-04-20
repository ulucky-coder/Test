#!/usr/bin/env node
// PreToolUse(Write) hook: enforce SVG safety rules.
// Blocks <script>, <foreignObject>, external xlink:href, and on* attributes.

let data = '';
process.stdin.on('data', chunk => (data += chunk));
process.stdin.on('end', () => {
  let input;
  try {
    input = JSON.parse(data);
  } catch {
    process.exit(0);
  }

  const path = input?.tool_input?.file_path || '';
  const content = input?.tool_input?.content || '';

  if (!path.endsWith('.svg')) process.exit(0);

  const violations = [];
  if (/<script[\s>]/i.test(content)) violations.push('<script> tag not allowed');
  if (/<foreignObject[\s>]/i.test(content)) violations.push('<foreignObject> not allowed');
  if (/\son\w+\s*=/i.test(content)) violations.push('on* event handlers not allowed');
  if (/xlink:href\s*=\s*["']https?:/i.test(content)) violations.push('external xlink:href not allowed');
  if (/<text[\s>]/i.test(content) && !path.includes('/specimens/')) {
    violations.push('<text> must be outlined to paths (except in type specimens)');
  }
  if (!/<title[>\s]/i.test(content)) violations.push('missing <title> element (accessibility)');

  if (violations.length > 0) {
    console.error('BLOCKED by pre-write-svg.js:');
    violations.forEach(v => console.error(`  - ${v}`));
    console.log(JSON.stringify({
      decision: 'block',
      reason: 'SVG safety violations: ' + violations.join('; ')
    }));
    process.exit(2);
  }

  process.exit(0);
});
