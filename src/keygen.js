// Key generator page: produces manager.private (password-protected) + manager.pub (public).
const MIN_PASSWORD = 8;

$('genKey').addEventListener('click', guard('genMsg', async () => {
  const name = $('newName').value.trim(), pw = $('newPass').value;
  if (!name) throw new Error('نام مدیر را وارد کنید');
  if (pw.length < MIN_PASSWORD) throw new Error(`رمز باید حداقل ${MIN_PASSWORD} نویسه باشد`);
  if (pw !== $('newPass2').value) throw new Error('تکرار رمز یکسان نیست');
  msg('genMsg', 'در حال ساخت کلید…', 'info');
  const { keyFile, pubFile } = await LC.generateIdentity(name, pw);
  downloadJson('manager.private', keyFile);
  downloadJson('manager.pub', pubFile);
  $('newPass').value = $('newPass2').value = '';
  msg('genMsg', 'دو فایل دانلود شد: manager.private و manager.pub', 'ok');
  msg('fpBox', `اثرانگشت: ${await LC.fingerprint(pubFile)}`, 'info');
}));
