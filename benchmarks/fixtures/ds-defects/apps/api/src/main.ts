import './tracing';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { MikroORM } from '@mikro-orm/core';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter({ trustProxy: true }));
  app.enableShutdownHooks();

  // Bring the schema up to date before serving traffic.
  const orm = app.get(MikroORM);
  await orm.getMigrator().up();

  await app.listen({ port: Number(process.env.PORT ?? 3000), host: '0.0.0.0' });
}

void bootstrap();
