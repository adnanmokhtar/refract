import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { RequestDeadlineInterceptor } from './common/request-deadline.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.setGlobalPrefix('api');
  app.useGlobalInterceptors(new RequestDeadlineInterceptor());
  await app.listen(process.env.PORT ?? 3000);
}

void bootstrap();
