let port;
let connected = false;
let snapshots = 0;
let openingSettings = 0;
async function disconnectIfIdle() {
  const connection = port;
  const revision = snapshots;
  if (!connection || openingSettings) return;
  let tabs;
  try { tabs = await chrome.tabs.query({url:'https://open.spotify.com/*'}); }
  catch { return; }
  // A new player may report while the tab query is still in flight.
  if (port !== connection || snapshots !== revision || openingSettings || tabs.length) return;
  port = undefined;
  connected = false;
  // Let the helper clear its playback session before it exits.
  connection.postMessage({kind:'disconnect',session:''});
}
function connect() {
  if (port) return port;
  const connection = chrome.runtime.connectNative('local.spotifymini.bridge');
  port = connection;
  connected = true;
  connection.onDisconnect.addListener(() => {
    void chrome.runtime.lastError;
    if (port !== connection) return;
    port = undefined;
    connected = false;
    openingSettings = 0;
  });
  const send = message => { if (port === connection) connection.postMessage(message); };
  connection.onMessage.addListener(async message => {
    if (port !== connection) return;
    if (message.kind === 'opened') {
      openingSettings = Math.max(0, openingSettings - 1);
      await disconnectIfIdle();
      return;
    }
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
        send({kind:'ack',session:'',commandID:message.id,error:'player-unavailable'});
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
      send({kind:'ack',session:'',commandID:message.id,error:result?.error || null});
      if (result?.playback) send({kind:'snapshot',session:'',snapshot:{tab:tabID,playback:result.playback}});
    } catch (error) {
      send({kind:'ack',session:'',commandID:message.id,error:'The Spotify tab is no longer available.'});
    }
  });
  return port;
}
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (message.kind === 'snapshot' && sender.tab?.id !== undefined && sender.url?.startsWith('https://open.spotify.com/')) {
    snapshots++;
    connect().postMessage({kind:'snapshot',session:'',snapshot:{tab:sender.tab.id,playback:message.playback}});
    respond({ok:true});
  } else if (message.kind === 'open' && !sender.tab) {
    const connection = connect();
    openingSettings++;
    connection.postMessage({kind:'open',session:''});
    respond({connected});
  }
});
chrome.tabs.onRemoved.addListener(tab => {
  port?.postMessage({kind:'closed',session:'',tab});
  return disconnectIfIdle();
});
chrome.tabs.onUpdated.addListener((tab, changes) => {
  if (changes.url && !changes.url.startsWith('https://open.spotify.com/')) {
    port?.postMessage({kind:'closed',session:'',tab});
  }
  // Completion also catches navigation to hosts whose URLs we cannot read.
  if (changes.url || changes.status === 'complete') return disconnectIfIdle();
});
