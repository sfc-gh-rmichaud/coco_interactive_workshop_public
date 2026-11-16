#!/usr/bin/env node
// Syntax-check every executable <script> block in the deck, so a broken slide
// literal fails here instead of as a blank page in front of the audience.
//   node tools/check_deck.js [presentation/index.html]
const fs = require("fs");
const path = process.argv[2] || "presentation/index.html";
// HTML comments mention "<script> tags" in prose; drop them before matching.
const html = fs.readFileSync(path, "utf8").replace(/<!--[\s\S]*?-->/g, "");
const re = /<script(?![^>]*application\/json)[^>]*>([\s\S]*?)<\/script>/g;
let m, count = 0, failed = 0;
while ((m = re.exec(html))) {
  count++;
  try { new Function(m[1]); } catch (e) { failed++; console.error(`script ${count}: ${e.message}`); }
}
console.log(`${path}: ${count} script blocks, ${failed} with syntax errors`);
process.exit(failed ? 1 : 0);
