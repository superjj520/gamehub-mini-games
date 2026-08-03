import { readdir, readFile } from 'node:fs/promises';

async function files(dir) {
  const result = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory()) result.push(...await files(path));
    else if (entry.name.endsWith('.js')) result.push(path);
  }
  return result;
}

const violations = [];
for (const file of await files('games')) {
  if (file.includes('/tests/')) continue;
  const source = await readFile(file, 'utf8');
  if (/supabase|runtime\/|\.\.\/[^/]+\//i.test(source)) violations.push(`${file} 违反游戏隔离边界`);
}
if (violations.length) { console.error(violations.join('\n')); process.exit(1); }
console.log('平台边界检查通过：游戏模块未引用旧运行时、Supabase 或其他游戏');
