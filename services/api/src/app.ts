import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config.js';
import { healthRouter } from './routes/health.js';
import { authRouter } from './routes/auth.js';
import { childrenRouter } from './routes/children.js';
import { childInvitesRouter } from './routes/childInvites.js';
import { devicesRouter } from './routes/devices.js';
import { zonesRouter } from './routes/zones.js';
import { locationRouter } from './routes/location.js';
import { panicRouter } from './routes/panic.js';
import { guardiansRouter } from './routes/guardians.js';
import { schoolsRouter } from './routes/schools.js';
import { reportsRouter } from './routes/reports.js';
import { routesRouter } from './routes/routes.js';
import { attendanceRouter } from './routes/attendance.js';
import { rewardsRouter } from './routes/rewards.js';
import { policiesRouter } from './routes/policies.js';
import { telemetryRouter } from './routes/telemetry.js';
import { messagesRouter } from './routes/messages.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export function createApp() {
  const app = express();

  app.use(
    helmet({
      contentSecurityPolicy: false,
    }),
  );
  app.use(
    cors({
      origin: config.CORS_ORIGIN === '*' ? true : config.CORS_ORIGIN.split(','),
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(morgan(config.NODE_ENV === 'production' ? 'combined' : 'dev'));

  app.use(healthRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/children', childrenRouter);
  app.use('/api/v1/child-invites', childInvitesRouter);
  app.use('/api/v1/devices', devicesRouter);
  app.use('/api/v1/zones', zonesRouter);
  app.use('/api/v1/location', locationRouter);
  app.use('/api/v1/panic', panicRouter);
  app.use('/api/v1/guardians', guardiansRouter);
  app.use('/api/v1/schools', schoolsRouter);
  app.use('/api/v1/reports', reportsRouter);
  app.use('/api/v1/routes', routesRouter);
  app.use('/api/v1/attendance', attendanceRouter);
  app.use('/api/v1/rewards', rewardsRouter);
  app.use('/api/v1/policies', policiesRouter);
  app.use('/api/v1/telemetry', telemetryRouter);
  app.use('/api/v1/messages', messagesRouter);

  // Phase 3 light school admin UI (static).
  app.use(
    '/school-admin',
    express.static(path.join(__dirname, '../public/school-admin')),
  );

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
