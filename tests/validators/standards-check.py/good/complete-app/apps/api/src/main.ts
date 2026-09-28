import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  // console.log('a comment, not a call'); fetch('also a comment')
  await app.listen(3000);
}
bootstrap();
