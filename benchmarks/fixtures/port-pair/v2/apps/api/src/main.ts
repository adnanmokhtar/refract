import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { configureApp } from './configure-app';
import { fastifyOptions } from './fastify-options';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter(fastifyOptions));
  configureApp(app);
  await app.listen({ port: Number(process.env.PORT ?? 3000), host: '0.0.0.0' });
}

void bootstrap();
