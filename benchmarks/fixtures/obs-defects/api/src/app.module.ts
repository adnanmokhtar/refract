import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { TerminusModule } from '@nestjs/terminus';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { LoggerModule } from 'nestjs-pino';
import config from './mikro-orm.config';
import { AuthController } from './auth/auth.controller';
import { CheckoutController } from './checkout/checkout.controller';
import { HealthController } from './health/health.controller';
import { CarrierWebhookController } from './webhooks/carrier-webhook.controller';
import { SERVICES } from './services';

@Module({
  imports: [
    MikroOrmModule.forRoot(config),
    BullModule.forRoot({ connection: { url: process.env.REDIS_URL } }),
    BullModule.registerQueue({ name: 'invoices' }),
    TerminusModule,

    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL ?? 'info',

        // Request logs go to stdout; the host's shipper picks them up from the container log.
        transport: { target: 'pino-pretty', options: { colorize: false, singleLine: true } },

        redact: {
          paths: [
            'req.headers.authorization',
            'req.headers.cookie',
            'req.headers["X-Partner-Token"]',
          ],
          censor: '[redacted]',
        },
      },
    }),
  ],
  controllers: [AuthController, CheckoutController, HealthController, CarrierWebhookController],
  providers: [...SERVICES],
})
export class AppModule {}
