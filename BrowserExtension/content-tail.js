
let reporting = false;
async function report() {
  if (reporting) return;
  reporting = true;
  try { await chrome.runtime.sendMessage({kind:'snapshot',playback:readPlayback()}); }
  catch { /* The extension may be reloaded while this tab remains open. */ }
  finally { reporting = false; }
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || message.kind !== 'command') return;
  if (/^seek(?:0|[1-9]0|100)$/.test(message.action)) {
    const slider = document.querySelector('[data-testid="playback-progressbar"] input[type="range"]');
    const percent = Number(message.action.slice(4));
    const min = Number(slider?.min), max = Number(slider?.max);
    const playback = readPlayback();
    if (!slider || slider.disabled || !playback.canControl || !Number.isFinite(min) ||
        !Number.isFinite(max) || max <= min || playback.duration <= 0) {
      respond({error:'Seeking is unavailable for this track.'}); return;
    }
    // Bypass React's value tracker so its existing range handler receives the change.
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(slider, String(min + (max - min) * percent / 100));
    slider.dispatchEvent(new Event('input', {bubbles:true}));
    slider.dispatchEvent(new Event('change', {bubbles:true}));
    respond({playback:readPlayback()});
    setTimeout(report, 150);
    return;
  }
  if (message.action === 'show') {
    const root = document.querySelector('[data-testid="now-playing-bar"]') ||
      document.querySelector('[data-testid="now-playing-widget"]');
    const title = readPlayback().title;
    const link = root?.querySelector('[data-testid="context-item-info-title"]')?.closest('a[href]') ||
      [...(root?.querySelectorAll('a[href]') || [])].find(element => title && element.textContent.trim() === title);
    // Use Spotify's own navigation so playback continues in this same tab.
    link?.click();
    respond({playback:readPlayback()});
    setTimeout(report, 150);
    return;
  }
  const controls = {toggle:'control-button-playpause',previous:'control-button-skip-back',next:'control-button-skip-forward'};
  const selector = controls[message.action];
  if (!selector) { respond({error:'Unknown command'}); return; }
  const button = document.querySelector(`[data-testid="${selector}"]`);
  if (!button || button.disabled) { respond({error:'This control is unavailable, for example during an advertisement.'}); return; }
  button.click();
  respond({playback:readPlayback()});
  setTimeout(report, 150);
});
setInterval(report, 2000);
let reportSoon;
const observer = new MutationObserver(() => {
  clearTimeout(reportSoon);
  reportSoon = setTimeout(report, 100);
});
const bar = document.querySelector('[data-testid="now-playing-bar"]') || document.querySelector('footer');
if (bar) observer.observe(bar, {subtree:true,childList:true,attributes:true,characterData:true});
report();
