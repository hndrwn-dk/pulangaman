import http from 'node:http';
import { createApp } from './app.js';
import { config } from './config.js';
import { initFirebase } from './firebase/admin.js';
import { attachWebSocketServer } from './ws/server.js';
import { startLocationPurgeJob } from './jobs/purgeLocations.js';
import { startUsageTelemetryPurgeJob } from './jobs/purgeUsageTelemetry.js';

initFirebase();

const app = createApp();
const server = http.createServer(app);
attachWebSocketServer(server);
startLocationPurgeJob();
startUsageTelemetryPurgeJob();

server.listen(config.PORT, () => {
  console.log(`PulangAman API listening on :${config.PORT}`);
});
