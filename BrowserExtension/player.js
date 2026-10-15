(() => {
  const root = document.querySelector('[data-testid="now-playing-bar"]') ||
    document.querySelector('[data-testid="now-playing-widget"]') || document;
  const metadata = navigator.mediaSession?.metadata;
  const play = document.querySelector('[data-testid="control-button-playpause"]');
  const text = selector => root.querySelector(selector)?.textContent?.trim() || '';
  const time = value => {
    const parts = (value || '').trim().split(':').map(Number);
    return parts.length <= 3 && parts.every(Number.isFinite)
      ? parts.reduce((total, part) => total * 60 + part, 0) : 0;
  };
  const title = text('[data-testid="context-item-info-title"]') || metadata?.title || '';
  const artist = [...root.querySelectorAll('a[href*="/artist/"]')]
    .map(element => element.textContent.trim()).filter(Boolean).join(', ') || metadata?.artist || '';
  const art = root.querySelector('img')?.src || metadata?.artwork?.[0]?.src || '';
  const titleLink = root.querySelector('[data-testid="context-item-info-title"]')?.closest('a[href]') ||
    [...root.querySelectorAll('a[href]')].find(link => link.textContent.trim() === title);
  let trackURL = titleLink?.href ||
    root.querySelector('a[href*="/track/"], a[href*="/episode/"], a[href*="highlight=spotify"], a[href*="uri=spotify"]')?.href || null;
  if (trackURL) {
    const params = new URL(trackURL, 'https://open.spotify.com').searchParams;
    const uri = params.get('uri') || params.get('highlight');
    const match = uri?.match(/^spotify:(track|episode):([A-Za-z0-9]{22})$/);
    if (match) trackURL = `https://open.spotify.com/${match[1]}/${match[2]}`;
  }
  if (title && (!trackURL || !/\/(track|episode)\/[A-Za-z0-9]{22}(?:[?#]|$)/.test(trackURL))) {
    // Spotify's Now Playing panel also exposes a track URI on its cover links.
    const links = document.querySelectorAll('a[href*="uri=spotify"], a[href*="highlight=spotify"]');
    for (const link of links) {
      if (link.textContent.trim() !== title && !link.getAttribute('aria-label')?.startsWith(`Now playing: ${title} by `)) continue;
      const params = new URL(link.href, 'https://open.spotify.com').searchParams;
      const match = (params.get('uri') || params.get('highlight'))?.match(/^spotify:(track|episode):([A-Za-z0-9]{22})$/);
      if (match) { trackURL = `https://open.spotify.com/${match[1]}/${match[2]}`; break; }
    }
  }
  const playing = navigator.mediaSession?.playbackState === 'playing' ||
    /pause/i.test(play?.getAttribute('aria-label') || '');
  return JSON.stringify({ title, artist, artwork: art, trackURL, playing,
    position: time(document.querySelector('[data-testid="playback-position"]')?.textContent),
    duration: time(document.querySelector('[data-testid="playback-duration"]')?.textContent),
    canControl: !!play && !play.disabled, updated: Date.now() / 1000, message: '' });
})()
