'use strict';

// ---------- Application Insights (must be first) ----------
const appInsights = require('applicationinsights');
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
  appInsights.setup().setSendLiveMetrics(true).start();
}
const aiClient = appInsights.defaultClient;

const express = require('express');
const cookieParser = require('cookie-parser');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');

const app = express();
const PORT = process.env.PORT || 8080;

const IMAGES_DIR = path.join(__dirname, 'images');
const THUMBS_DIR = path.join(__dirname, 'thumbs');

// ---------- Middleware ----------
app.use(cookieParser());
app.use(express.urlencoded({ extended: false }));

// CSRF: Double Submit Cookie — set token cookie on every response if missing
app.use((req, res, next) => {
  if (!req.cookies.csrf_token) {
    const token = crypto.randomBytes(32).toString('hex');
    res.cookie('csrf_token', token, {
      path: '/',
      httpOnly: false,        // JS must read it
      sameSite: 'Strict',
      secure: req.secure || req.headers['x-forwarded-proto'] === 'https',
    });
    req.csrfToken = token;
  } else {
    req.csrfToken = req.cookies.csrf_token;
  }
  next();
});

// Serve static files from public/ (disable index so our route handles /)
app.use(express.static(path.join(__dirname, 'public'), { index: false }));

// Serve images and thumbs
app.use('/images', express.static(IMAGES_DIR));
app.use('/thumbs', express.static(THUMBS_DIR));

// Inject CSRF token into index.html
app.get('/', (req, res) => {
  const htmlPath = path.join(__dirname, 'public', 'index.html');
  let html = fs.readFileSync(htmlPath, 'utf8');
  html = html.replace('{{CSRF_TOKEN}}', req.csrfToken);
  res.type('html').send(html);
});

// ---------- CSRF validation helper ----------
function validateCsrf(req, res) {
  const cookieToken = req.cookies.csrf_token || '';
  const postToken = req.body.csrf_token || '';
  if (!cookieToken || !postToken || cookieToken.length !== postToken.length) {
    res.status(403).send('Invalid CSRF token');
    return false;
  }
  // Constant-time comparison
  if (!crypto.timingSafeEqual(Buffer.from(cookieToken), Buffer.from(postToken))) {
    res.status(403).send('Invalid CSRF token');
    return false;
  }
  return true;
}

// ---------- API: Get thumbnails ----------
app.get('/api/thumbs', (req, res) => {
  if (!fs.existsSync(THUMBS_DIR)) return res.json([]);

  const allowed = new Set(['jpg', 'jpeg', 'png', 'gif', 'webp']);
  const files = fs.readdirSync(THUMBS_DIR)
    .filter(f => allowed.has(path.extname(f).toLowerCase().slice(1)))
    .sort();
  res.json(files);
});

// ---------- API: List images by extension ----------
app.get('/api/images', (req, res) => {
  const allowedExts = new Set(['jpg', 'jpeg', 'png']);
  const ext = (req.query.ext || '').toLowerCase();

  if (!allowedExts.has(ext)) {
    return res.status(400).send('Invalid extension');
  }

  if (!fs.existsSync(IMAGES_DIR)) return res.send('No images found');

  const files = fs.readdirSync(IMAGES_DIR)
    .filter(f => path.extname(f).toLowerCase().slice(1) === ext);

  if (files.length === 0) return res.send('No images found');

  const html = files
    .map(f => f.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]))
    .join('\n<br/>') + '\n<br/>';
  res.send(html);
});

// ---------- API: Convert images ----------
app.post('/api/process', async (req, res) => {
  if (!validateCsrf(req, res)) return;

  const imageCount = parseInt(req.body.images, 10);
  if (isNaN(imageCount) || imageCount < 1 || imageCount > 100) {
    return res.status(400).send('Invalid image count');
  }

  // Intentional 403 for the troubleshooting tutorial:
  // Selecting more than 3 images triggers an error for Azure Monitor diagnostics.
  if (imageCount > 3) {
    const msg = `403 — Too many images selected (${imageCount})`;
    console.error(msg);
    if (aiClient) {
      aiClient.trackException({ exception: new Error(msg) });
    }
    return res.status(403).send('Too many images selected — limit is 3 per batch.');
  }

  // Parse and whitelist image names (must match imgNN.jpg pattern)
  const imgNames = (req.body.imgNames || '').split(',').filter(Boolean);
  const allowed = /^img\d{1,3}\.(jpg|jpeg)$/i;

  for (const name of imgNames) {
    if (!allowed.test(name)) {
      return res.status(400).send('Invalid image name');
    }
  }

  // Convert each image to PNG using sharp
  for (const name of imgNames) {
    const source = path.join(IMAGES_DIR, name);
    if (!fs.existsSync(source)) continue;

    const outName = 'converted_' + path.parse(name).name + '.png';
    const dest = path.join(IMAGES_DIR, outName);
    await sharp(source).png().toFile(dest);
  }

  res.send('OK');
});

// ---------- API: Delete converted images ----------
app.post('/api/delete', (req, res) => {
  if (!validateCsrf(req, res)) return;

  if (!fs.existsSync(IMAGES_DIR)) return res.send('No images found');

  const pattern = /^converted_.*\.png$/i;
  const entries = fs.readdirSync(IMAGES_DIR).filter(f => pattern.test(f));

  if (entries.length === 0) return res.send('No images found');

  const results = [];
  for (const entry of entries) {
    const filepath = path.join(IMAGES_DIR, entry);
    try {
      fs.unlinkSync(filepath);
      results.push('Deleted ' + entry);
    } catch {
      results.push('Error deleting ' + entry);
    }
  }
  res.send(results.join('<br/>\n'));
});

// ==========================================================
// Intentional errors for troubleshooting demos
// ==========================================================

// 1) Memory Leak — each call pushes ~1 MB into an array that is never freed.
//    Repeated calls will cause RSS / heap to climb until the container OOMs.
const _leakyStore = [];

app.get('/api/leak', (req, res) => {
  const chunk = Buffer.alloc(1024 * 1024, 'x');   // 1 MB
  _leakyStore.push(chunk);
  const totalMB = _leakyStore.length;
  console.warn(`[DEMO] Memory leak: retained ${totalMB} MB so far`);
  if (aiClient) {
    aiClient.trackEvent({
      name: 'MemoryLeakDemo',
      properties: { retainedMB: String(totalMB) },
    });
  }
  res.json({ retainedMB: totalMB, message: `Leaked ~${totalMB} MB total` });
});

// 2) CPU Spike — blocks the event loop with a heavy synchronous loop (~3-4 s).
//    While running, the server cannot handle any other requests.
app.get('/api/spike', (_req, res) => {
  console.warn('[DEMO] CPU spike: blocking event loop…');
  if (aiClient) {
    aiClient.trackEvent({ name: 'CpuSpikeDemo' });
  }
  const start = Date.now();
  // Burn CPU for ~3 seconds
  while (Date.now() - start < 3000) {
    Math.sqrt(Math.random() * Number.MAX_SAFE_INTEGER);
  }
  const elapsed = Date.now() - start;
  res.json({ blockedMs: elapsed, message: `Event loop blocked for ${elapsed} ms` });
});

// 3) Unhandled Exception — throws after a short delay, crashing the process.
//    In App Service this triggers an automatic restart and shows up in diagnostics.
app.get('/api/crash', (_req, res) => {
  console.error('[DEMO] Crash: throwing unhandled exception in 500 ms…');
  if (aiClient) {
    aiClient.trackException({ exception: new Error('Intentional crash for troubleshooting demo') });
    aiClient.flush();
  }
  res.json({ message: 'Crash scheduled — the process will exit in ~500 ms.' });
  setTimeout(() => {
    throw new Error('Intentional unhandled exception — troubleshooting demo');
  }, 500);
});

// ---------- Start ----------
app.listen(PORT, () => {
  console.log(`Image Converter running on port ${PORT}`);
});
