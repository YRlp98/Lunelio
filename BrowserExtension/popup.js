const manifest = chrome.runtime.getManifest();
document.querySelector('#version').textContent = manifest.version_name || manifest.version;

document.querySelector('#show').addEventListener('click', async () => {
  const status = document.querySelector('#status');
  try {
    await chrome.runtime.sendMessage({kind:'open'});
    status.textContent = 'If settings did not open, use the Lunelio menu on your Mac.';
  } catch {
    status.textContent = 'Install and open Lunelio for Mac first.';
  }
});
