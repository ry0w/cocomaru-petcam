const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 8080;

// --- Static file serving ---
const STATIC_DIR = path.join(__dirname, 'public');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
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

function serveStatic(req, res) {
  let urlPath = req.url.split('?')[0];
  let filePath = path.join(STATIC_DIR, urlPath === '/' ? 'index.html' : urlPath);

  if (!filePath.startsWith(STATIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(STATIC_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  try {
    const data = fs.readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
}

// --- Rate limiter ---
// IP単位で join_room の試行回数を制限（ブルートフォース防止）
const rateLimits = new Map(); // ip -> { count, resetAt }
const RATE_LIMIT_MAX = 5;          // 最大試行回数
const RATE_LIMIT_WINDOW_MS = 60000; // 1分間

function isRateLimited(ip) {
  const now = Date.now();
  let entry = rateLimits.get(ip);

  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
    rateLimits.set(ip, entry);
  }

  entry.count++;
  return entry.count > RATE_LIMIT_MAX;
}

// 古いエントリを定期削除
setInterval(() => {
  const now = Date.now();
  for (const [ip, entry] of rateLimits) {
    if (now > entry.resetAt) rateLimits.delete(ip);
  }
}, 60000);

// --- Room management ---
const rooms = new Map();

function generateRoomId() {
  // 英数字12桁（約62^12 = 3.2×10^21 通り、推測不可能）
  return crypto.randomBytes(9).toString('base64url').slice(0, 12);
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

function cleanupRoom(roomId) {
  const room = rooms.get(roomId);
  if (room) {
    if (room.camera) {
      try { room.camera.close(); } catch (_) {}
    }
    if (room.viewer) {
      try { room.viewer.close(); } catch (_) {}
    }
    rooms.delete(roomId);
    console.log(`[Room ${roomId.slice(0, 4)}...] Cleaned up`);
  }
}

// --- HTTP + WebSocket server ---
const server = http.createServer(serveStatic);
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  let currentRoom = null;
  let role = null;

  // クライアントIPを取得（プロキシ対応）
  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim()
           || req.socket.remoteAddress
           || 'unknown';

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }));
      return;
    }

    switch (msg.type) {
      // カメラがルームを作成（パスワード必須）
      case 'create_room': {
        const password = msg.password;
        if (!password || password.length < 4) {
          ws.send(JSON.stringify({ type: 'error', message: 'パスワードは4文字以上で設定してください' }));
          return;
        }

        const roomId = generateRoomId();
        rooms.set(roomId, {
          camera: ws,
          viewer: null,
          passwordHash: hashPassword(password),
        });
        currentRoom = roomId;
        role = 'camera';
        ws.send(JSON.stringify({ type: 'room_created', roomId }));
        console.log(`[Room ${roomId.slice(0, 4)}...] Created by camera`);
        break;
      }

      // ビューワーがルームに参加（パスワード検証 + レート制限）
      case 'join_room': {
        // レート制限チェック
        if (isRateLimited(ip)) {
          ws.send(JSON.stringify({
            type: 'error',
            message: '試行回数が多すぎます。1分後に再試行してください',
          }));
          console.log(`[Rate limit] ${ip} blocked`);
          return;
        }

        const roomId = msg.roomId;
        const password = msg.password;
        const room = rooms.get(roomId);

        if (!room) {
          ws.send(JSON.stringify({ type: 'error', message: 'ルームが見つかりません' }));
          return;
        }
        if (room.viewer) {
          ws.send(JSON.stringify({ type: 'error', message: 'ルームは満員です' }));
          return;
        }

        // パスワード検証
        if (hashPassword(password || '') !== room.passwordHash) {
          ws.send(JSON.stringify({ type: 'error', message: 'パスワードが間違っています' }));
          return;
        }

        room.viewer = ws;
        currentRoom = roomId;
        role = 'viewer';
        ws.send(JSON.stringify({ type: 'room_joined', roomId }));
        if (room.camera && room.camera.readyState === 1) {
          room.camera.send(JSON.stringify({ type: 'viewer_connected' }));
        }
        console.log(`[Room ${roomId.slice(0, 4)}...] Viewer joined`);
        break;
      }

      case 'offer':
      case 'answer':
      case 'candidate': {
        if (!currentRoom) {
          ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
          return;
        }
        const room = rooms.get(currentRoom);
        if (!room) return;
        const target = role === 'camera' ? room.viewer : room.camera;
        if (target && target.readyState === 1) {
          target.send(JSON.stringify(msg));
        }
        break;
      }

      case 'leave': {
        if (currentRoom) {
          const room = rooms.get(currentRoom);
          if (room) {
            const other = role === 'camera' ? room.viewer : room.camera;
            if (other && other.readyState === 1) {
              other.send(JSON.stringify({ type: 'peer_disconnected' }));
            }
            cleanupRoom(currentRoom);
          }
          currentRoom = null;
          role = null;
        }
        break;
      }

      default:
        ws.send(JSON.stringify({ type: 'error', message: `Unknown type: ${msg.type}` }));
    }
  });

  ws.on('close', () => {
    if (currentRoom) {
      const room = rooms.get(currentRoom);
      if (room) {
        const other = role === 'camera' ? room.viewer : room.camera;
        if (other && other.readyState === 1) {
          other.send(JSON.stringify({ type: 'peer_disconnected' }));
        }
        cleanupRoom(currentRoom);
      }
    }
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err.message);
  });
});

// Periodic log
setInterval(() => {
  if (rooms.size > 0) {
    console.log(`Active rooms: ${rooms.size}`);
  }
}, 60000);

server.listen(PORT, '0.0.0.0', () => {
  console.log('============================================');
  console.log('  ココ丸ちゃんねる サーバー起動');
  console.log(`  http://localhost:${PORT}`);
  console.log('============================================');
});
