let port;
let connected = false;
function connect() {
  if (port) return port;
  port = chrome.runtime.connectNative('local.spotifymini.bridge');
  connected = true;
  port.onDisconnect.addListener(() => {
    void chrome.runtime.lastError;
    port = undefined;
    connected = false;
  });
  port.onMessage.addListener(async message => {
    if (message.kind !== 'command' || !Number.isInteger(message.tab)) return;
    try {
      let tabID = message.tab;
      let tab = await chrome.tabs.get(tabID).catch(() => undefined);
      if (!tab?.url?.startsWith('https://open.spotify.com/')) {
        tab = undefined;
        if (message.action === 'show' || message.action === 'toggle') {
          const spotify = await chrome.tabs.query({url:'https://open.spotify.com/*'});
          tab = spotify.find(candidate => candidate.active) || spotify[0];
        }
      }
      if (!tab) {
        port?.postMessage({kind:'ack',session:'',commandID:message.id,error:'player-unavailable'});
        return;
      }
      tabID = tab.id;
      if (message.action === 'show') {
        await chrome.tabs.update(tabID, {active:true});
        const window = await chrome.windows.get(tab.windowId);
        await chrome.windows.update(tab.windowId, window.state === 'minimized'
          ? {state:'normal',focused:true} : {focused:true});
      }
      const result = await chrome.tabs.sendMessage(tabID, {kind:'command',action:message.action});
      port?.postMessage({kind:'ack',session:'',commandID:message.id,error:result?.error || null});
      if (result?.playback) port?.postMessage({kind:'snapshot',session:'',snapshot:{tab:tabID,playback:result.playback}});
    } catch (error) {
      port?.postMessage({kind:'ack',session:'',commandID:message.id,error:'The Spotify tab is no longer available.'});
    }
  });
  return port;
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.kind === 'snapshot' && sender.tab?.id !== undefined && sender.url?.startsWith('https://open.spotify.com/')) {
    connect().postMessage({kind:'snapshot',session:'',snapshot:{tab:sender.tab.id,playback:message.playback}});
    respond({ok:true});
  } else if (message.kind === 'open' && !sender.tab) {
    connect().postMessage({kind:'open',session:''});
    respond({connected});
  }
});
chrome.tabs.onRemoved.addListener(tab => {
  port?.postMessage({kind:'closed',session:'',tab});
});
chrome.tabs.onUpdated.addListener((tab, changes) => {
  if (changes.url && !changes.url.startsWith('https://open.spotify.com/')) {
    port?.postMessage({kind:'closed',session:'',tab});
  }
});
