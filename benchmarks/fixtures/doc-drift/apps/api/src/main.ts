import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, type NestFastifyApplication } from '@nestjs/platform-fastify';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

import { AppModule } from './app.module';
import { loadConfig } from './config/config.loader';

async function bootstrap(): Promise<void> {
  const config = loadConfig();
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ logger: { level: config.LOG_LEVEL } }),
  );
  app.setGlobalPrefix('v1', { exclude: ['metrics', 'health'] });

  const spec = new DocumentBuilder().setTitle('Tallyhook API').setVersion('1.5.0').build();
  SwaggerModule.setup('docs', app, () => SwaggerModule.createDocument(app, spec));

  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}

void bootstrap();
