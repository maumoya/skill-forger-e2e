// Record a web page through the Chrome DevTools screencast (used by make_demo.sh).
// Usage: node record_page.mjs PORT URL OUT_DIR SECONDS [WIDTH] [HEIGHT]
// Writes OUT_DIR/f00000.jpg ... and OUT_DIR/times.json (seconds since start, one per frame). Local only.
// A page that defines window.demoSeek(ms) is stepped frame by frame at 15 fps (deterministic, no clock drift);
// any other page is recorded live through the screencast.
import fs from 'node:fs';
const [port, url, out, secs, width = '1200', height = '760'] = process.argv.slice(2);
const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const ws = new WebSocket(list.find(t => t.type === 'page').webSocketDebuggerUrl);
let id = 0; const pending = new Map(); let n = 0; const t0 = Date.now(); const times = [];
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
ws.onmessage = e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
  if (m.method === 'Page.screencastFrame') {
    fs.writeFileSync(`${out}/f${String(n++).padStart(5, '0')}.jpg`, Buffer.from(m.params.data, 'base64'));
    times.push((Date.now() - t0) / 1000);
    send('Page.screencastFrameAck', { sessionId: m.params.sessionId });
  }
};
await new Promise(r => (ws.onopen = r));
await send('Emulation.setDeviceMetricsOverride', { width: +width, height: +height, deviceScaleFactor: 1, mobile: false });
await send('Page.enable');
await send('Page.navigate', { url });
await new Promise(r => setTimeout(r, 4000));
const seek = await send('Runtime.evaluate', { expression: "typeof window.demoSeek === 'function'", returnByValue: true });
if (seek?.result?.value === true) {
  for (let ms = 0; ms < secs * 1000; ms += 1000 / 15) {
    await send('Runtime.evaluate', { expression: `window.demoSeek(${ms})`, awaitPromise: true });
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 85 });
    fs.writeFileSync(`${out}/f${String(n++).padStart(5, '0')}.jpg`, Buffer.from(shot.data, 'base64'));
    times.push(ms / 1000);
  }
} else {
  await send('Page.startScreencast', { format: 'jpeg', quality: 85 });
  await new Promise(r => setTimeout(r, secs * 1000));
  await send('Page.stopScreencast');
}
fs.writeFileSync(`${out}/times.json`, JSON.stringify(times));
console.log(`recorded ${n} frames`);
process.exit(0);
