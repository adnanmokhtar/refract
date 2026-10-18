import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import * as http from './common/http-setup';

export function configureApp(app: NestFastifyApplication): void {
  app.setGlobalPrefix('api', { exclude: ['up'] });
  app.useGlobalFilters(...http.globalFilters());
  http.registerCsrf(app);
  app.enableShutdownHooks();
}
