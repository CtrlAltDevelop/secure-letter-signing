// Builds three self-contained, offline HTML files: keygen, employee, manager.
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';

const read = (p) => readFileSync(new URL(p, import.meta.url), 'utf8');
// Vazirmatn (SIL OFL) embedded as base64 so pages stay single-file and offline.
const fontFace = (file, weight) =>
  `@font-face{font-family:Vazirmatn;font-weight:${weight};font-style:normal;font-display:swap;` +
  `src:url(data:font/woff2;base64,${readFileSync(new URL(`./src/fonts/${file}`, import.meta.url)).toString('base64')}) format('woff2')}`;
const fonts = [fontFace('Vazirmatn-Regular.woff2', 400), fontFace('Vazirmatn-Bold.woff2', 700)].join('\n');
const common = {
  '/*STYLE*/': read('./src/style.css').replace('/*FONT*/', () => fonts),
  '/*CRYPTO*/': read('./src/crypto.js').replace(/\nif \(typeof module[\s\S]*$/, '\n'),
  '/*SHARED*/': read('./src/shared.js'),
};
const pages = {
  keygen: '🔑 ساخت کلید مدیر (یک بار)',
  manager: '🔏 پنل مدیر',
  employee: '📨 پنل کارمند (تیم اداری)',
};

mkdirSync(new URL('./dist/', import.meta.url), { recursive: true });
rmSync(new URL('./dist/letter-signing.html', import.meta.url), { force: true });
for (const [name, title] of Object.entries(pages)) {
  let html = read('./src/layout.html')
    .replaceAll('{{TITLE}}', title)
    .replace('{{BODY}}', () => read(`./src/pages/${name}.html`));
  for (const [marker, code] of Object.entries({ ...common, '/*APP*/': read(`./src/${name}.js`) })) html = html.replace(marker, () => code);
  writeFileSync(new URL(`./dist/${name}.html`, import.meta.url), html);
  console.log(`dist/${name}.html  ${(html.length / 1024).toFixed(1)} KB`);
}
