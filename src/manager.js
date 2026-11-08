// Manager page: unlock private key, open encrypted letter, approve / request revision / reject, sign.
let ident = null;
let openedLetter = null;

const refreshSignBtn = () => { $('signBtn').disabled = !(ident && openedLetter); };
const setUnlocked = () => msg('keyStatus', `باز است: ${ident.name} — اثرانگشت: ${ident.fp}`, 'ok');

$('unlock').addEventListener('click', guard('keyMsg', async () => {
  const f = $('keyFile').files[0];
  if (!f) throw new Error('فایل کلید را انتخاب کنید');
  msg('keyMsg', 'در حال باز کردن…', 'info');
  ident = await LC.unlockIdentity(await readJson(f), $('unlockPass').value);
  $('unlockPass').value = '';
  setUnlocked(); msg('keyMsg', '');
  refreshSignBtn();
}));

$('letterFile').addEventListener('change', guard('openMsg', async (e) => {
  const f = e.target.files[0]; if (!f) return;
  openedLetter = null; refreshSignBtn(); $('mgrPreview').replaceChildren();
  if (!ident) throw new Error('ابتدا کلید خود را باز کنید');
  openedLetter = await LC.decryptLetter(await readJson(f), ident);
  show('mgrPreview', await renderLetter({ letter: openedLetter }));
  msg('openMsg', openedLetter.rev > 1 ? `نامه با موفقیت باز شد (ویرایش ${openedLetter.rev})` : 'نامه با موفقیت باز شد', 'ok');
  refreshSignBtn();
}));

document.querySelectorAll('input[name=decision]').forEach((r) => r.addEventListener('change', () => {
  $('noteLabel').textContent = r.value === 'revision' && r.checked ? 'توضیح (الزامی): چه چیزی باید اصلاح شود؟' : 'توضیح (اختیاری)';
}));

// signature pad
const pad = $('pad'), pg = pad.getContext('2d');
let drawing = false, padDirty = false;
pg.lineWidth = 3; pg.lineCap = 'round'; pg.lineJoin = 'round'; pg.strokeStyle = '#0F203A';
const pos = (e) => { const r = pad.getBoundingClientRect(); return [(e.clientX - r.left) * pad.width / r.width, (e.clientY - r.top) * pad.height / r.height]; };
pad.addEventListener('pointerdown', (e) => { drawing = true; pad.setPointerCapture(e.pointerId); pg.beginPath(); pg.moveTo(...pos(e)); });
pad.addEventListener('pointermove', (e) => { if (!drawing) return; pg.lineTo(...pos(e)); pg.stroke(); padDirty = true; });
['pointerup', 'pointercancel'].forEach((t) => pad.addEventListener(t, () => { drawing = false; }));
const clearPad = () => { pg.clearRect(0, 0, pad.width, pad.height); padDirty = false; };
$('padClear').addEventListener('click', clearPad);
$('sigUpload').addEventListener('change', guard('signMsg', async (e) => {
  const f = e.target.files[0]; if (!f) return;
  const img = await loadImg(await readDataUrl(f));
  clearPad();
  const s = Math.min(pad.width / img.width, pad.height / img.height);
  pg.drawImage(img, (pad.width - img.width * s) / 2, (pad.height - img.height * s) / 2, img.width * s, img.height * s);
  padDirty = true;
}));

$('signBtn').addEventListener('click', guard('signMsg', async () => {
  const decision = document.querySelector('input[name=decision]:checked').value;
  const note = $('note').value.trim();
  if (decision === 'revision' && !note) throw new Error('برای «نیاز به اصلاح» توضیح بنویسید');
  if (!padDirty) throw new Error('تصویر امضا را بکشید یا بارگذاری کنید');
  const signed = await LC.signLetter(ident, { letter: openedLetter, decision, note, sigImage: pad.toDataURL('image/png') });
  downloadJson(`signed-${safeName(openedLetter.no)}-v${openedLetter.rev || 1}.signed`, signed);
  const p = signed.payload;
  show('mgrPreview', await renderLetter({ letter: p.letter, signed: signedView(p, { hash: await LC.docHash(p), verified: false }) }));
  msg('signMsg', 'نامه امضا شد؛ فایل .signed را برای تیم اداری بفرستید', 'ok');
}));
