import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { MikroORM } from '@mikro-orm/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter({ trustProxy: true }));

  // Bring the schema up to date before taking traffic.
  await app.get(MikroORM).getMigrator().up();

  await app.listen(3000, '0.0.0.0');
}

void bootstrap();
