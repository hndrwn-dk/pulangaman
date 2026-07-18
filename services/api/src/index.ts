import http from 'node:http';
import { createApp } from './app.js';
import { config } from './config.js';
import { initFirebase } from './firebase/admin.js';
import { attachWebSocketServer } from './ws/server.js';

initFirebase();

const app = createApp();
const server = http.createServer(app);
attachWebSocketServer(server);

server.listen(config.PORT, () => {
  console.log(`PulangAman API listening on :${config.PORT}`);
});
