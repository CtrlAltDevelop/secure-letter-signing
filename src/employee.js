// Employee (admin team) page: write letters, send encrypted, verify signed replies, edit & resend.
let managerPub = store.get('lc_pub', null);
let thread = null;       // { id, no, rev, prevHash } of the letter being edited
let draft = null;        // last previewed letter
let draftCanvas = null;
let signedCanvas = null;
let lastVerified = null; // { payload, hash } of the loaded .signed file

function nextLetterNo() {
  const n = store.get('lc_counter', 0) + 1; store.set('lc_counter', n);
  return `${jalali().replace(/\//g, '')}-${String(n).padStart(4, '0')}`;
}

// ---------- tabs ----------
function showTab(name) {
  document.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('on', b.dataset.tab === name));
  for (const t of ['create', 'signed']) $('tab-' + t).classList.toggle('hidden', t !== name);
}
document.querySelectorAll('[data-tab]').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));

initSplit('sp-create'); initSplit('sp-signed');

// ---------- manager public key ----------
function refreshPub() {
  const has = !!managerPub;
  msg('pubStatus', has ? `مدیر: ${managerPub.name} — اثرانگشت: ${managerPub.fp}` : 'هنوز کلیدی ثبت نشده است.', has ? 'ok' : 'info');
  $('pubClear').classList.toggle('hidden', !has);
  $('setup').open = !has; // first run: show the setup block until a key is registered
}
refreshPub();

$('pubFile').addEventListener('change', guard('pubStatus', async (e) => {
  const f = e.target.files[0]; if (!f) return;
  managerPub = await LC.checkPub(await readJson(f));
  if (!store.set('lc_pub', managerPub)) throw new Error('ذخیره‌سازی مرورگر در دسترس نیست؛ کلید فقط تا بستن صفحه معتبر است');
  refreshPub();
}));
$('pubClear').addEventListener('click', () => { managerPub = null; store.del('lc_pub'); refreshPub(); });

// ---------- letterhead ----------
const currentHead = () => store.get('lc_head', DEFAULT_HEAD);
(() => { const h = currentHead(); $('hName').value = h.name; $('hSub').value = h.sub; $('hAddr').value = h.address; })();
$('hSave').addEventListener('click', guard('hMsg', async () => {
  const logoFile = $('hLogo').files[0];
  const logo = logoFile ? await readDataUrl(logoFile) : currentHead().logo;
  if (!store.set('lc_head', { name: $('hName').value, sub: $('hSub').value, address: $('hAddr').value, logo })) throw new Error('ذخیره‌سازی مرورگر در دسترس نیست');
  msg('hMsg', 'ذخیره شد (روی نامه‌های بعدی اعمال می‌شود)', 'ok');
}));
$('hLogoClear').addEventListener('click', () => { store.set('lc_head', { ...currentHead(), logo: '' }); $('hLogo').value = ''; msg('hMsg', 'لوگو حذف شد', 'ok'); });

// ---------- editor ----------
function invalidateDraft() { $('dlLetter').disabled = $('dlLetterPng').disabled = true; }
['subject', 'body'].forEach((id) => $(id).addEventListener('input', invalidateDraft));

function setEditorTitle() {
  $('editorTitle').textContent = thread && thread.rev > 1 ? `ویرایش نامه ${ltr(thread.no)} (نسخه ${thread.rev})` : 'نامه‌ی جدید';
}

$('mkPreview').addEventListener('click', guard('adminMsg', async () => {
  const subject = $('subject').value.trim(), body = $('body').value.trim();
  if (!subject || !body) throw new Error('موضوع و متن نامه را وارد کنید');
  thread = thread || { id: LC.uuid(), no: nextLetterNo(), rev: 1 };
  draft = { ...thread, date: jalali(), subject, body, head: currentHead(), createdAt: new Date().toISOString() };
  draftCanvas = await renderLetter({ letter: draft });
  show('letterPreview', draftCanvas);
  $('dlLetterPng').disabled = false;
  $('dlLetter').disabled = !managerPub;
  setEditorTitle();
  setPane('sp-create', 'preview');
  msg('adminMsg', managerPub ? '' : 'برای ساخت فایل رمزشده ابتدا کلید عمومی مدیر را ثبت کنید', managerPub ? '' : 'bad');
}));

$('dlLetter').addEventListener('click', guard('adminMsg', async () => {
  if (!managerPub) throw new Error('کلید عمومی مدیر ثبت نشده است');
  downloadJson(`letter-${safeName(draft.no)}-v${draft.rev}.letter`, await LC.encryptLetter(draft, managerPub));
  msg('adminMsg', 'فایل رمزشده ساخته شد؛ آن را برای مدیر بفرستید', 'ok');
}));
$('dlLetterPng').addEventListener('click', async () => download(`letter-${safeName(draft.no)}-v${draft.rev}.png`, await canvasBlob(draftCanvas)));

$('newLetter').addEventListener('click', () => {
  thread = null; draft = null; $('subject').value = ''; $('body').value = ''; setPane('sp-create', 'form');
  $('letterPreview').replaceChildren(); msg('revBanner', ''); msg('adminMsg', ''); invalidateDraft(); setEditorTitle();
});

// ---------- verify signed reply ----------
$('signedFile').addEventListener('change', guard('verifyMsg', async (e) => {
  const f = e.target.files[0]; if (!f) return;
  $('printSigned').disabled = $('dlSignedPng').disabled = true; $('reviseBtn').classList.add('hidden');
  $('signedPreview').replaceChildren(); lastVerified = null;
  if (!managerPub) throw new Error('ابتدا کلید عمومی مدیر را ثبت کنید');
  const r = await LC.verifySigned(await readJson(f), managerPub);
  if (!r.ok) { msg('verifyMsg', '✖ ' + r.reason, 'bad'); return; }
  const p = r.payload, when = new Date(p.signedAt);
  lastVerified = r;
  msg('verifyMsg', `✔ امضا معتبر است — ${p.signer.name} — ${jalali(when)} ${timeHM(when)}\nنظر مدیر: ${DECISION_FA[p.decision] || p.decision}`, p.decision === 'approved' ? 'ok' : 'warn');
  signedCanvas = await renderLetter({ letter: p.letter, signed: signedView(p, { hash: r.hash, verified: true }) });
  show('signedPreview', signedCanvas);
  $('printSigned').disabled = $('dlSignedPng').disabled = false;
  $('reviseBtn').classList.toggle('hidden', p.decision === 'approved');
  setPane('sp-signed', 'preview');
}));
$('printSigned').addEventListener('click', guard('verifyMsg', async () => {
  const img = $('printImg');
  // print only after the image has loaded, else the page prints blank.
  // (img.decode() is not used: it never settles while the image is inside a display:none container.)
  await new Promise((resolve, reject) => {
    img.onload = resolve;
    img.onerror = () => reject(new Error('آماده‌سازی تصویر چاپ ناموفق بود'));
    img.src = signedCanvas.toDataURL('image/png');
  });
  window.print();
}));
$('dlSignedPng').addEventListener('click', async () => download('signed-letter.png', await canvasBlob(signedCanvas)));

// ---------- edit & resend ----------
$('reviseBtn').addEventListener('click', () => {
  const { payload: p, hash } = lastVerified;
  thread = { id: p.letter.id, no: p.letter.no, rev: (p.letter.rev || 1) + 1, prevHash: hash };
  $('subject').value = p.letter.subject; $('body').value = p.letter.body;
  draft = null; $('letterPreview').replaceChildren(); invalidateDraft(); setEditorTitle();
  msg('revBanner', `درخواست مدیر (${DECISION_FA[p.decision]}):\n${p.note || '— بدون توضیح —'}`, 'warn');
  msg('adminMsg', 'متن را اصلاح کنید، پیش‌نمایش بزنید و فایل جدید را برای مدیر بفرستید', 'info');
  showTab('create'); setPane('sp-create', 'form');
  $('subject').scrollIntoView({ behavior: 'smooth', block: 'center' });
});
