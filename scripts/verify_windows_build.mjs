import fs from "node:fs";
import path from "node:path";

const buildPath = path.resolve(process.argv[2] ?? "build/windows/新时代觉醒者.exe");
if (!fs.existsSync(buildPath)) throw new Error(`Windows 构建不存在：${buildPath}`);
const stat = fs.statSync(buildPath);
if (stat.size < 1024 * 1024) throw new Error(`Windows 构建体积异常：${stat.size} bytes`);

const file = fs.openSync(buildPath, "r");
const header = Buffer.alloc(4096);
try {
  fs.readSync(file, header, 0, header.length, 0);
} finally {
  fs.closeSync(file);
}
if (header.toString("ascii", 0, 2) !== "MZ") throw new Error("Windows 构建缺少 MZ DOS 头");
const peOffset = header.readUInt32LE(0x3c);
if (header.toString("ascii", peOffset, peOffset + 4) !== "PE\0\0") throw new Error("Windows 构建缺少 PE 签名");
const machine = header.readUInt16LE(peOffset + 4);
if (machine !== 0x8664) throw new Error(`Windows 构建架构不是 x86_64：0x${machine.toString(16)}`);

console.log(`Windows 构建结构验证通过：${path.relative(process.cwd(), buildPath)}；${stat.size} bytes；PE x86_64`);
console.log("目标设备状态：未验证；仍需在 Windows 10/11、1080p、键鼠和手柄环境启动回归");
