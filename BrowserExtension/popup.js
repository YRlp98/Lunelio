const manifest = chrome.runtime.getManifest();
document.querySelector('#version').textContent = 'Connector ' + (manifest.version_name || manifest.version);

async function openSettings() {
  const status = document.querySelector('#status');
  status.textContent = 'Opening Lunelio…';
  try {
    const response = await chrome.runtime.sendMessage({kind:'open'});
    if (!response?.connected) throw new Error('Lunelio did not open');
    status.textContent = 'Lunelio Settings is open.';
  } catch {
    status.textContent = 'Install and open Lunelio for Mac first.';
  }
}

document.querySelector('#show').addEventListener('click', openSettings);

function versionParts(version) {
  if (typeof version !== 'string' || !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version)) return;
  const parts = version.split('.').map(Number);
  return parts.every(Number.isSafeInteger) ? parts : undefined;
}

async function checkForUpdates() {
  try {
    const installed = versionParts(manifest.version);
    if (!installed) return;
    const response = await fetch('https://api.github.com/repos/YRlp98/Lunelio/releases/latest', {
      headers:{Accept:'application/vnd.github+json'}, credentials:'omit', signal:AbortSignal.timeout(10000)
    });
    if (!response.ok) return;
    const release = await response.json();
    if (release.draft !== false || release.prerelease !== false) return;
    const version = typeof release.tag_name === 'string' ? release.tag_name.replace(/^v/, '') : '';
    const latest = versionParts(version);
    if (!latest) return;
    const difference = latest.findIndex((part, index) => part !== installed[index]);
    const newer = difference < 0 ? manifest.version_name?.startsWith(manifest.version + '-') : latest[difference] > installed[difference];
    if (!newer) return;
    const tag = document.querySelector('#update');
    tag.title = 'Download Lunelio ' + version + ' from GitHub';
    tag.hidden = false;
  } catch {
    // Offline or rate-limited checks must not interrupt the connector.
  }
}

void checkForUpdates();
