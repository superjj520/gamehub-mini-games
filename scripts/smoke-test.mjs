import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { chromium } from 'playwright';

const root = process.cwd();
const port = 4173;
const pages = ['index.html', 'wheel-page.html', 'game-2048.html', 'leaderboard.html', 'builder-v2.html', 'play.html'];
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' };

const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = normalize(join(root, pathname === '/' ? 'index.html' : pathname.slice(1)));
    if (!file.startsWith(root)) throw new Error('非法路径');
    const body = await readFile(file);
    response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream' });
    response.end(body);
  } catch {
    response.writeHead(404);
    response.end('Not found');
  }
});

await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
const browser = await chromium.launch({ headless: true });
const failures = [];

for (const pageName of pages) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  try {
    const response = await page.goto(`http://127.0.0.1:${port}/${pageName}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    if (!response || !response.ok()) errors.push(`HTTP ${response?.status() || '未知'}`);
  } catch (error) {
    errors.push(error.message);
  }
  if (errors.length) failures.push(`${pageName}:\n  ${errors.join('\n  ')}`);
  await page.close();
}

await browser.close();
server.close();

if (failures.length) {
  console.error('页面冒烟测试失败：\n' + failures.join('\n\n'));
  process.exit(1);
}

console.log(`页面冒烟测试通过：${pages.length} 个关键页面`);
