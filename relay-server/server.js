const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT || "8080", 10);
const MAX_ROOM_SIZE = 5;
const IDLE_TIMEOUT_MS = 90_000;
const MAX_MESSAGE_SIZE = 2 * 1024 * 1024; // 2MB

// rooms: Map<roomId, Map<ws, { deviceId, deviceName, platform }>>
const rooms = new Map();
// wsToRoom: Map<ws, roomId>
const wsToRoom = new Map();
// wsAlive: Map<ws, timestamp>
const wsAlive = new Map();

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE_SIZE });

wss.on("connection", (ws) => {
  wsAlive.set(ws, Date.now());

  ws.on("message", (raw) => {
    wsAlive.set(ws, Date.now());

    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
      return;
    }

    switch (msg.type) {
      case "join":
        handleJoin(ws, msg);
        break;
      case "relay":
        handleRelay(ws, msg);
        break;
      case "ping":
        ws.send(JSON.stringify({ type: "pong" }));
        break;
      case "leave":
        handleLeave(ws);
        break;
      default:
        ws.send(
          JSON.stringify({ type: "error", message: `Unknown type: ${msg.type}` })
        );
    }
  });

  ws.on("close", () => {
    handleLeave(ws);
    wsAlive.delete(ws);
  });

  ws.on("error", () => {
    handleLeave(ws);
    wsAlive.delete(ws);
  });
});

function handleJoin(ws, msg) {
  const { roomId, deviceId, deviceName, platform } = msg;

  if (!roomId || !deviceId || typeof roomId !== "string") {
    ws.send(JSON.stringify({ type: "error", message: "Missing roomId or deviceId" }));
    return;
  }

  // Leave any current room first
  handleLeave(ws);

  // Get or create room
  if (!rooms.has(roomId)) {
    rooms.set(roomId, new Map());
  }
  const room = rooms.get(roomId);

  // Check room capacity
  if (room.size >= MAX_ROOM_SIZE) {
    ws.send(JSON.stringify({ type: "error", message: "Room is full" }));
    return;
  }

  const memberInfo = {
    deviceId: deviceId,
    deviceName: deviceName || "Unknown",
    platform: platform || "Unknown",
  };

  room.set(ws, memberInfo);
  wsToRoom.set(ws, roomId);

  // Send joined confirmation with current member list
  const members = [];
  for (const [, info] of room) {
    members.push({
      deviceId: info.deviceId,
      deviceName: info.deviceName,
      platform: info.platform,
    });
  }
  ws.send(JSON.stringify({ type: "joined", roomId, members }));

  // Notify other room members
  for (const [peer] of room) {
    if (peer !== ws && peer.readyState === 1) {
      peer.send(
        JSON.stringify({
          type: "peer_joined",
          deviceId: memberInfo.deviceId,
          deviceName: memberInfo.deviceName,
          platform: memberInfo.platform,
        })
      );
    }
  }

  console.log(
    `[${roomId.slice(0, 8)}] ${memberInfo.deviceName} joined (${room.size} members)`
  );
}

function handleRelay(ws, msg) {
  const roomId = wsToRoom.get(ws);
  if (!roomId) {
    ws.send(JSON.stringify({ type: "error", message: "Not in a room" }));
    return;
  }

  const room = rooms.get(roomId);
  if (!room) return;

  const senderInfo = room.get(ws);
  if (!senderInfo) return;

  const outgoing = JSON.stringify({
    type: "relay",
    payload: msg.payload,
    from: senderInfo.deviceId,
  });

  for (const [peer] of room) {
    if (peer !== ws && peer.readyState === 1) {
      peer.send(outgoing);
    }
  }
}

function handleLeave(ws) {
  const roomId = wsToRoom.get(ws);
  if (!roomId) return;

  const room = rooms.get(roomId);
  if (!room) return;

  const memberInfo = room.get(ws);
  room.delete(ws);
  wsToRoom.delete(ws);

  // Notify remaining members
  if (memberInfo) {
    for (const [peer] of room) {
      if (peer.readyState === 1) {
        peer.send(
          JSON.stringify({
            type: "peer_left",
            deviceId: memberInfo.deviceId,
          })
        );
      }
    }
    console.log(
      `[${roomId.slice(0, 8)}] ${memberInfo.deviceName} left (${room.size} members)`
    );
  }

  // Clean up empty rooms
  if (room.size === 0) {
    rooms.delete(roomId);
  }
}

// Idle timeout sweep — disconnect WebSockets that haven't sent anything in 90s
setInterval(() => {
  const now = Date.now();
  for (const [ws, lastActive] of wsAlive) {
    if (now - lastActive > IDLE_TIMEOUT_MS) {
      console.log("[timeout] Closing idle connection");
      ws.terminate();
      wsAlive.delete(ws);
    }
  }
}, 30_000);

server.listen(PORT, "0.0.0.0", () => {
  console.log(`CopyPasta relay server running on port ${PORT}`);
});
