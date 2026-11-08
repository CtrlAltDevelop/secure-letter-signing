// Helpers + canvas letter renderer shared by the employee and manager pages.
// All user text goes through textContent / canvas, never innerHTML.
const FONT = 'Vazirmatn, Tahoma, "Segoe UI", system-ui, sans-serif';
const DEFAULT_HEAD = { name: 'نام شرکت نمونه', sub: 'Sample Company Co.', address: 'تهران، خیابان نمونه، پلاک ۱ — تلفن: ۰۲۱-۰۰۰۰۰۰۰۰', logo: '' };
const DECISION_FA = { approved: 'تأیید شد', rejected: 'رد شد', revision: 'نیاز به اصلاح' };
const DECISION_COLOR = { approved: '#047857', rejected: '#b91c1c', revision: '#b45309' };
const $ = (id) => document.getElementById(id);

const store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { console.warn('storage read failed', e); return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); return true; } catch (e) { console.warn('storage write failed', e); return false; } },
  del(k) { try { localStorage.removeItem(k); } catch (e) { console.warn('storage delete failed', e); } },
};

function msg(id, text, kind = 'info') { const el = $(id); el.textContent = text; el.className = 'msg ' + (text ? kind : ''); }
const readJson = async (file) => { try { return JSON.parse(await file.text()); } catch { throw new Error('فایل خوانده نشد (JSON نامعتبر)'); } };
const readDataUrl = (file) => new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = () => rej(new Error('خواندن فایل ناموفق بود')); r.readAsDataURL(file); });
const loadImg = (src) => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => rej(new Error('تصویر بارگذاری نشد')); i.src = src; });

function download(name, blob) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob); a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}
const downloadJson = (name, obj) => download(name, new Blob([JSON.stringify(obj)], { type: 'application/json' }));
const canvasBlob = (c) => new Promise((res) => c.toBlob(res, 'image/png'));
const safeName = (s) => s.replace(/[^\w\-]+/g, '_');

function jalali(d = new Date()) {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-u-ca-persian-nu-latn', { year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(d).map((x) => [x.type, x.value]));
  return `${p.year}/${p.month}/${p.day}`;
}
const ltr = (s) => `⁦${s}⁩`; // keep digits/hex in logical order inside RTL text
const timeHM = (d) => d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });

// run async handlers; surface errors in a message box
const guard = (msgId, fn) => async (...a) => { try { await fn(...a); } catch (e) { console.error(e); msg(msgId, e.message || String(e), 'bad'); } };

function wrap(ctx, text, maxW) {
  const out = [];
  for (const para of String(text).split('\n')) {
    if (!para.trim()) { out.push(''); continue; }
    let line = '';
    for (const w of para.split(/\s+/)) {
      const t = line ? line + ' ' + w : w;
      if (line && ctx.measureText(t).width > maxW) { out.push(line); line = w; } else line = t;
    }
    out.push(line);
  }
  return out;
}

// letter = {no, rev, date, subject, body, head}; signed = {decision, note, sigImage, signerName, signedAt, fp, hash, verified}
async function renderLetter({ letter, signed }) {
  const W = 794, M = 56, SCALE = 2, LH = 28, INK = '#111';
  const head = letter.head || DEFAULT_HEAD;
  const logo = head.logo ? await loadImg(head.logo) : null;
  const sigImg = signed?.sigImage ? await loadImg(signed.sigImage) : null;

  const probe = document.createElement('canvas').getContext('2d');
  probe.direction = 'rtl'; probe.font = `16px ${FONT}`;
  const body = wrap(probe, letter.body, W - 2 * M);
  const note = signed?.note ? wrap(probe, signed.note, W - 2 * M) : [];

  let H = 150 + 90 + 40 + body.length * LH + 40;
  if (signed) H += 70 + note.length * 26 + 150 + 40;
  H = Math.max(1123, H + 90);

  const c = document.createElement('canvas');
  c.width = W * SCALE; c.height = H * SCALE;
  const g = c.getContext('2d');
  g.scale(SCALE, SCALE);
  g.fillStyle = '#fff'; g.fillRect(0, 0, W, H);
  g.direction = 'rtl'; g.textBaseline = 'alphabetic';
  const R = W - M;
  const text = (s, x, y, { size = 16, bold = false, align = 'right', color = INK } = {}) => {
    g.font = `${bold ? 'bold ' : ''}${size}px ${FONT}`; g.fillStyle = color; g.textAlign = align; g.fillText(s, x, y);
  };
  const rule = (y, color = '#1d4ed8', w = 1.5) => { g.strokeStyle = color; g.lineWidth = w; g.beginPath(); g.moveTo(M, y); g.lineTo(R, y); g.stroke(); };

  let textRight = R;
  if (logo) { const s = 72 / Math.max(logo.width, logo.height); g.drawImage(logo, R - logo.width * s, 36, logo.width * s, logo.height * s); textRight = R - logo.width * s - 16; }
  text(head.name, textRight, 64, { size: 24, bold: true, color: '#1d4ed8' });
  text(head.sub, textRight, 92, { size: 14, color: '#555' });
  rule(122);

  const rev = letter.rev > 1 ? `  (ویرایش ${letter.rev})` : '';
  text(`شماره: ${ltr(letter.no)}${rev}`, R, 156, { size: 14 });
  text(`تاریخ: ${ltr(letter.date)}`, M, 156, { size: 14, align: 'left' });
  text(`موضوع: ${letter.subject}`, R, 196, { size: 17, bold: true });

  let y = 240;
  for (const l of body) { text(l, R, y); y += LH; }

  if (signed) {
    y += 20; rule(y, '#bbb', 1); y += 34;
    text(`نظر مدیر: ${DECISION_FA[signed.decision] || signed.decision}`, R, y, { size: 18, bold: true, color: DECISION_COLOR[signed.decision] || INK }); y += 30;
    for (const l of note) { text(l, R, y); y += 26; }
    y += 10;
    if (sigImg) {
      const s = Math.min(220 / sigImg.width, 90 / sigImg.height);
      g.drawImage(sigImg, M + 10, y, sigImg.width * s, sigImg.height * s);
    }
    const d = new Date(signed.signedAt);
    text(signed.signerName, M + 120, y + 112, { size: 14, bold: true, align: 'center' });
    text(`${ltr(jalali(d))}  ${ltr(timeHM(d))}`, M + 120, y + 134, { size: 12, color: '#555', align: 'center' });
    if (signed.verified) text('✔ امضای دیجیتال معتبر', R, y + 40, { size: 15, bold: true, color: '#047857' });
    text(`شناسه سند: ${ltr(signed.hash)}`, R, y + 72, { size: 11, color: '#555' });
    text(`اثرانگشت امضاکننده: ${ltr(signed.fp)}`, R, y + 92, { size: 11, color: '#555' });
  }

  rule(H - 56, '#bbb', 1);
  text(head.address, W / 2, H - 30, { size: 12, color: '#555', align: 'center' });
  return c;
}

const show = (containerId, canvas) => $(containerId).replaceChildren(canvas);
const signedView = (p, extra) => ({ ...p, signerName: p.signer.name, fp: p.signer.fp, ...extra });
