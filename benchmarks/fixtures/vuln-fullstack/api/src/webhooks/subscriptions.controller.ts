import { Controller, ForbiddenException, Get, Header, Param, Query } from '@nestjs/common';
import { timingSafeEqual } from 'crypto';
import { WEBHOOK_SUBSCRIPTIONS } from './webhook-subscriptions';

function sameText(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

@Controller('webhooks')
export class SubscriptionsController {
  @Get(':provider/subscribe')
  @Header('Content-Type', 'text/plain')
  subscribe(@Param('provider') provider: string, @Query() query: Record<string, string>) {
    const sub = Object.hasOwn(WEBHOOK_SUBSCRIPTIONS, provider) ? WEBHOOK_SUBSCRIPTIONS[provider] : undefined;
    const configured = sub ? process.env[sub.verifyTokenEnv] : undefined;
    if (!sub || !configured || !sameText(String(query[sub.tokenParam] ?? ''), configured)) {
      throw new ForbiddenException();
    }
    return String(query[sub.challengeParam] ?? '');
  }
}
