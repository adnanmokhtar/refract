import { NestFastifyApplication } from '@nestjs/platform-fastify';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import multipart from '@fastify/multipart';
import { filesPlugin } from './files/files.plugin';
import { importsPlugin } from './imports/imports.plugin';
import { fxRoutes } from './fx/fx.routes';
import { catalogExportRoutes } from './catalog/catalog-export.routes';
import { tenantHook } from './tenancy/tenant.hook';
import { registerLegacyRoutes } from './legacy/legacy-routes';
import { deprecationHook } from './legacy/deprecation.hook';

export async function configureApp(app: NestFastifyApplication): Promise<void> {
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.register(multipart, { limits: { fileSize: 25 * 1024 * 1024, files: 1 } });
  await app.register(tenantHook);
  await app.register(deprecationHook);
  await app.register(filesPlugin, { prefix: '/v1/files' });
  await app.register(importsPlugin, { prefix: '/v1/imports' });
  await app.register(fxRoutes);
  await app.register(catalogExportRoutes);
  registerLegacyRoutes(app);

  const config = new DocumentBuilder().setTitle('Lumen Orders').setVersion('2.4.0').build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);
}
