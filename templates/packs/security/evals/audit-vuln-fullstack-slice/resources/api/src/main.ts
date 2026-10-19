import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import { join } from 'path';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/all-exceptions.filter';
import { config } from './config';

async function bootstrap() {
  // rawBody: the webhook controller verifies provider signatures over the exact bytes.
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { rawBody: true });

  app.setGlobalPrefix('api');
  app.use(helmet());
  app.use(cookieParser());
  app.enableCors({ origin: config.publicUrl, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ transform: true }));
  app.useGlobalFilters(new AllExceptionsFilter());

  // Product images are written under public/uploads. nginx serves the same volume in
  // production; this mount covers local development and direct-to-pod health checks.
  app.useStaticAssets(join(process.cwd(), 'public'));

  const openapi = new DocumentBuilder()
    .setTitle('Marketly API')
    .setVersion('1.8.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, openapi));

  await app.listen(config.port);
}

void bootstrap();
