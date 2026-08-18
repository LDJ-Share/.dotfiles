// Regenerates themes/vs2026-parity-color-theme.json + package.json from the two
// upstream marketplace themes. The committed outputs are the source of truth —
// run this only when re-deriving from fresh upstream versions. See README.md
// for how to fetch the vendor inputs (not committed; re-downloadable .vsix).
import fs from 'node:fs';
import path from 'node:path';

const here = import.meta.dirname;
const vendor = path.join(here, 'vendor');

function parseJsonc(text) {
  let out = '', inStr = false, inLine = false, inBlock = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i], n = text[i + 1];
    if (inLine) { if (c === '\n') { inLine = false; out += c; } continue; }
    if (inBlock) { if (c === '*' && n === '/') { inBlock = false; i++; } continue; }
    if (inStr) { out += c; if (c === '\\') { out += n; i++; } else if (c === '"') inStr = false; continue; }
    if (c === '"') { inStr = true; out += c; continue; }
    if (c === '/' && n === '/') { inLine = true; continue; }
    if (c === '/' && n === '*') { inBlock = true; i++; continue; }
    out += c;
  }
  return JSON.parse(out.replace(/,\s*([}\]])/g, '$1'));
}
const base = parseJsonc(fs.readFileSync(path.join(vendor, 'ZTex275.dark-theme-vs2026/extension/themes/dark-color-theme.json'), 'utf8'));
const vs2022 = parseJsonc(fs.readFileSync(path.join(vendor, 'SoVoKaN.dark-theme-vs2022/extension/themes/dark-color-theme.json'), 'utf8'));

const theme = {
  name: 'VS2026 Dark (VS Parity)',
  semanticHighlighting: true,
  // VS2022 theme's workbench colors (user preference over the VS2026 fork's Cursor-styled UI)
  colors: vs2022.colors,
  semanticTokenColors: { ...base.semanticTokenColors },
  tokenColors: [...base.tokenColors],
};

// ---- semantic fixes (pixel-verified against VS 2026 screenshots) ----
const sem = theme.semanticTokenColors;
sem['namespace'] = { foreground: '#DCDCDCFF' };            // VS renders namespaces plain, not gray
sem['member'] = { foreground: '#DCDCAAFF' };               // TS emits "member" for methods
sem['field:csharp'] = { foreground: '#DCDCDCFF' };
sem['extensionMethod'] = { foreground: '#DCDCAAFF' };
sem['recordClass'] = { foreground: '#4EC9B0FF' };
sem['recordStruct'] = { foreground: '#86C691FF' };
sem['operatorOverloaded'] = { foreground: '#B4B4B4FF' };
sem['stringEscapeCharacter'] = { foreground: '#FFD68FFF' };
// VS doc comments: dim green body/tags, gray attribute values
for (const t of ['xmlDocCommentText', 'xmlDocCommentDelimiter', 'xmlDocCommentName',
  'xmlDocCommentComment', 'xmlDocCommentCDataSection', 'xmlDocCommentEntityReference',
  'xmlDocCommentProcessingInstruction', 'xmlDocCommentAttributeName']) {
  sem[t] = { foreground: '#608B4EFF' };
}
sem['xmlDocCommentAttributeValue'] = { foreground: '#C8C8C8FF' };
sem['xmlDocCommentAttributeQuotes'] = { foreground: '#C8C8C8FF' };
// TS/JS: properties are light blue in VS (C# keeps plain via the unscoped rule above)
for (const lang of ['typescript', 'typescriptreact', 'javascript', 'javascriptreact']) {
  sem[`property:${lang}`] = { foreground: '#9CDCFEFF' };
  sem[`typeParameter:${lang}`] = { foreground: '#4EC9B0FF' };
}

// ---- TextMate fixes ----
const tsLangs = ['source.ts', 'source.tsx', 'source.js', 'source.jsx'];
theme.tokenColors.push(
  { name: 'C# XML doc comment (fallback)', scope: ['comment.block.documentation.cs', 'comment.documentation.cs', 'comment.documentation.attribute.name.cs'], settings: { foreground: '#608B4EFF' } },
  { name: 'C# XML doc attribute value (fallback)', scope: ['comment.documentation.attribute.value.cs', 'comment.documentation.attribute.quotes.cs'], settings: { foreground: '#C8C8C8FF' } },
  { name: 'TS/JS strings (VS uses the VS Code string red here)', scope: tsLangs.flatMap(l => [`${l} string`, `${l} punctuation.definition.string`]), settings: { foreground: '#CE9178FF' } },
  { name: 'TS/JS control + import keywords (VS purple for scripts)', scope: tsLangs.map(l => `${l} keyword.control`), settings: { foreground: '#C586C0FF' } },
  { name: 'TS/JS expression keywords stay blue (new/typeof/in/of/as)', scope: ['keyword.operator.new', 'keyword.operator.expression'], settings: { foreground: '#569CD6FF' } },
  { name: 'TS/JS object literal keys', scope: 'meta.object-literal.key', settings: { foreground: '#9CDCFEFF' } },
  { name: 'TS/JS variables (fallback when semantic tokens absent)', scope: tsLangs.map(l => `${l} variable.other`), settings: { foreground: '#9CDCFEFF' } },
  { name: 'TS/JS primitive type annotations', scope: ['support.type.primitive', 'support.type.builtin'], settings: { foreground: '#569CD6FF' } },
);

// ---- emit into this directory (the committed extension source) ----
fs.writeFileSync(path.join(here, 'themes', 'vs2026-parity-color-theme.json'), JSON.stringify(theme, null, 2));
fs.writeFileSync(path.join(here, 'package.json'), JSON.stringify({
  name: 'vs2026-dark-parity',
  displayName: 'VS2026 Dark (VS Parity)',
  description: 'Visual Studio 2026 syntax colors for VS Code — derived from ZTex275.dark-theme-vs2026, pixel-matched against real VS 2026 for TypeScript and C#, with the VS2022 theme workbench backgrounds.',
  version: '1.0.0',
  publisher: 'mkrauz',
  engines: { vscode: '^1.70.0' },
  categories: ['Themes'],
  contributes: { themes: [{ label: 'VS2026 Dark (VS Parity)', uiTheme: 'vs-dark', path: './themes/vs2026-parity-color-theme.json' }] },
}, null, 2));
console.log('written:', here);
console.log('semantic keys:', Object.keys(theme.semanticTokenColors).length, '| tokenColors:', theme.tokenColors.length, '| workbench colors:', Object.keys(theme.colors).length);
