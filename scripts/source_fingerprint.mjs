import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve("gta-reference-runtime");
const ignoredDirectories = new Set([".godot", ".import"]);
const ignoredGeneratedExtensions = new Set([".gdc", ".remap"]);

function collect(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...collect(fullPath));
    } else if (
      entry.isFile()
      && !entry.name.endsWith(".import")
      && !entry.name.endsWith(".uid")
      && ![...ignoredGeneratedExtensions].some((extension) => entry.name.endsWith(extension))
    ) {
      files.push(fullPath);
    }
  }
  return files;
}

const hash = crypto.createHash("sha256");
const files = collect(root);
for (const filePath of files) {
  const relativePath = path.relative(root, filePath).split(path.sep).join("/");
  hash.update(relativePath);
  hash.update("\0");
  hash.update(fs.readFileSync(filePath));
  hash.update("\0");
}

console.log(`${hash.digest("hex")} files=${files.length}`);
