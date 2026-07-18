import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config.js';
import { healthRouter } from './routes/health.js';
import { authRouter } from './routes/auth.js';
import { childrenRouter } from './routes/children.js';
import { devicesRouter } from './routes/devices.js';
import { zonesRouter } from './routes/zones.js';
import { locationRouter } from './routes/location.js';
import { panicRouter } from './routes/panic.js';
import { guardiansRouter } from './routes/guardians.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';

export function createApp() {
  const app = express();

  app.use(helmet());
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
  app.use('/api/v1/devices', devicesRouter);
  app.use('/api/v1/zones', zonesRouter);
  app.use('/api/v1/location', locationRouter);
  app.use('/api/v1/panic', panicRouter);
  app.use('/api/v1/guardians', guardiansRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
