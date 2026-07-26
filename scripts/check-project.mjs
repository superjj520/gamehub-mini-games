import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const roots = ['.'];
const ignored = new Set(['node_modules', '.git', 'wheel-v0-files', 'wheelcut/_next']);
const files = [];

async function walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    const relative = path.replace(/^\.\//, '');
    if (ignored.has(entry.name) || ignored.has(relative)) continue;
    if (entry.isDirectory()) await walk(path);
    else if (entry.isFile() && /\.(js|mjs|cjs)$/.test(entry.name)) files.push(path);
  }
}

for (const root of roots) await walk(root);

const failures = [];
await Promise.all(files.map((file) => new Promise((resolve) => {
  const child = spawn(process.execPath, ['--check', file], { stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = '';
  child.stderr.on('data', (chunk) => { stderr += chunk; });
  child.on('close', (code) => {
    if (code !== 0) failures.push(`${file}\n${stderr.trim()}`);
    resolve();
  });
})));

if (failures.length) {
  console.error('JavaScript 语法检查失败：\n' + failures.join('\n\n'));
  process.exit(1);
}

console.log(`JavaScript 语法检查通过：${files.length} 个文件`);
