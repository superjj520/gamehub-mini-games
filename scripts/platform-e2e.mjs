import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, normalize } from 'node:path';
import { chromium } from 'playwright';

const root = process.cwd(), port = 4174;
const server = createServer(async (req, res) => {
  try {
    const path = normalize(join(root, new URL(req.url, 'http://x').pathname.replace(/^\//, '') || 'index.html'));
    if (!path.startsWith(root)) throw Error();
    res.end(await readFile(path));
  } catch { res.statusCode = 404; res.end(); }
});
await new Promise((resolve) => server.listen(port, resolve));
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
try {
  await page.goto(`http://127.0.0.1:${port}/create-v2.html`);
  await page.getByRole('button', { name: '发布并获取链接' }).click();
  const link = await page.getByRole('link', { name: '打开玩家页' }).getAttribute('href');
  if (!link) throw new Error('发布后未生成玩家链接');
  await page.goto(`http://127.0.0.1:${port}/${link}`);
  await page.getByRole('button', { name: '开始抽奖' }).click();
  await page.locator('#result').waitFor({ state: 'visible', timeout: 6000 });
  await page.getByRole('button', { name: '再玩一次' }).click();
  if (await page.getByText('编辑此游戏').count()) throw new Error('玩家页不应有编辑入口');
} finally { await browser.close(); server.close(); }
console.log('大转盘创建、发布、游玩端到端测试通过');
