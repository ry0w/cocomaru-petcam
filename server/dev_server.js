const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Flutter Webビルド出力を HTTPS で配信する開発サーバー
// WebRTCのカメラアクセスには HTTPS が必要です（localhost以外）

const WEB_PORT = process.env.WEB_PORT || 8443;
const WEB_HTTP_PORT = process.env.WEB_HTTP_PORT || 8080;
const BUILD_DIR = path.join(__dirname, '..', 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
};

function handleRequest(req, res) {
  // CORS headers for development
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  let filePath = path.join(BUILD_DIR, req.url === '/' ? 'index.html' : req.url);

  // Prevent directory traversal
  if (!filePath.startsWith(BUILD_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // SPA fallback: if file doesn't exist, serve index.html
  if (!fs.existsSync(filePath)) {
    filePath = path.join(BUILD_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  try {
    const data = fs.readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  } catch (err) {
    res.writeHead(404);
    res.end('Not found');
  }
}

// Check for certs
const certPath = path.join(__dirname, 'certs', 'localhost.pem');
const keyPath = path.join(__dirname, 'certs', 'localhost-key.pem');

if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  const server = https.createServer({
    cert: fs.readFileSync(certPath),
    key: fs.readFileSync(keyPath),
  }, handleRequest);

  server.listen(WEB_PORT, '0.0.0.0', () => {
    console.log('============================================');
    console.log('  ココ丸ちゃんねる Web Preview (HTTPS)');
    console.log('============================================');
    console.log(`  https://localhost:${WEB_PORT}`);
    console.log(`  https://${getLocalIP()}:${WEB_PORT}`);
    console.log('============================================');
    console.log(`  配信元: ${BUILD_DIR}`);
    console.log('');
  });
} else {
  const server = http.createServer(handleRequest);
  server.listen(WEB_HTTP_PORT, '0.0.0.0', () => {
    console.log('============================================');
    console.log('  ココ丸ちゃんねる Web Preview (HTTP)');
    console.log('============================================');
    console.log(`  http://localhost:${WEB_HTTP_PORT}`);
    console.log('');
    console.log('  ⚠ HTTPではカメラにアクセスできません');
    console.log('    HTTPS有効化: ./generate_certs.sh');
    console.log('============================================');
    console.log(`  配信元: ${BUILD_DIR}`);
    console.log('');
  });
}

function getLocalIP() {
  const { networkInterfaces } = require('os');
  const nets = networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        return net.address;
      }
    }
  }
  return 'localhost';
}
