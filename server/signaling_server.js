const http = require('http');
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

  // Prevent directory traversal
  if (!filePath.startsWith(STATIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // SPA fallback
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

// --- Room management ---
const rooms = new Map();

function generateRoomId() {
  return String(Math.floor(100000 + Math.random() * 900000));
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
    console.log(`[Room ${roomId}] Cleaned up`);
  }
}

// --- HTTP + WebSocket server ---
const server = http.createServer(serveStatic);
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  let currentRoom = null;
  let role = null;

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }));
      return;
    }

    switch (msg.type) {
      case 'create_room': {
        const roomId = generateRoomId();
        rooms.set(roomId, { camera: ws, viewer: null });
        currentRoom = roomId;
        role = 'camera';
        ws.send(JSON.stringify({ type: 'room_created', roomId }));
        console.log(`[Room ${roomId}] Created by camera`);
        break;
      }

      case 'join_room': {
        const roomId = msg.roomId;
        const room = rooms.get(roomId);
        if (!room) {
          ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
          return;
        }
        if (room.viewer) {
          ws.send(JSON.stringify({ type: 'error', message: 'Room is full' }));
          return;
        }
        room.viewer = ws;
        currentRoom = roomId;
        role = 'viewer';
        ws.send(JSON.stringify({ type: 'room_joined', roomId }));
        if (room.camera && room.camera.readyState === 1) {
          room.camera.send(JSON.stringify({ type: 'viewer_connected' }));
        }
        console.log(`[Room ${roomId}] Viewer joined`);
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
    console.log(`Client disconnected (role: ${role}, room: ${currentRoom})`);
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err.message);
  });
});

// Periodic log of active rooms
setInterval(() => {
  if (rooms.size > 0) {
    console.log(`Active rooms: ${rooms.size}`);
  }
}, 60000);

server.listen(PORT, '0.0.0.0', () => {
  console.log('============================================');
  console.log('  ココ丸ちゃんねる サーバー起動');
  console.log(`  http://localhost:${PORT}`);
  console.log(`  WebSocket: ws://localhost:${PORT}`);
  console.log(`  Static: ${STATIC_DIR}`);
  console.log('============================================');
});
