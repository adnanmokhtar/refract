import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { WsAdapter } from '@nestjs/platform-ws';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    // Seller feed uploads are up to 50 MB gzipped.
    new FastifyAdapter({ bodyLimit: 60 * 1024 * 1024, trustProxy: true }),
  );

  app.setGlobalPrefix('api');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.useWebSocketAdapter(new WsAdapter(app));
  app.enableShutdownHooks();

  // Feeds arrive as application/gzip; the upload handler wants the raw bytes.
  app
    .getHttpAdapter()
    .getInstance()
    .addContentTypeParser('application/gzip', { parseAs: 'buffer' }, (_req, body, done) => done(null, body));

  await app.listen({ port: Number(process.env.PORT ?? 3000), host: '0.0.0.0' });
}

void bootstrap();
