import { NestFactory } from '@nestjs/core';
import { AdminModule } from './admin.module';

async function bootstrap() {
  const app = await NestFactory.create(AdminModule);

  // SIGTERM runs the module destroy hooks and closes the HTTP server before exit.
  app.enableShutdownHooks();

  // PORT and HOSTNAME are set by the platform (the kubelet sets HOSTNAME to the pod name).
  const port = Number(process.env.PORT ?? 3000);
  console.log(`admin console on ${process.env.HOSTNAME}:${port}`);
  await app.listen(port);
}

void bootstrap();
