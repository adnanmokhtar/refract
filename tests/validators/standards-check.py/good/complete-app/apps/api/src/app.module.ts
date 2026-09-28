import { Module, Controller, Get } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
@Controller()
export class HealthController { @Get('readyz') ready() { return { ok: true }; } }
@Module({ imports: [ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }])], controllers: [HealthController] })
export class AppModule {}
