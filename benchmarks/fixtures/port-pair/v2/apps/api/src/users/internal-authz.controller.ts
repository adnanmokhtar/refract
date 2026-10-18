import { Controller, ForbiddenException, Get, Headers, HttpCode } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';

// nginx auth_request target for /exports/* (deploy/nginx/facade.conf): the caller must be signed
// in (the global JwtAuthGuard ran) and the link must carry a valid, unexpired V1-style signature.
@Controller('internal/authz')
export class InternalAuthzController {
  @Get('export')
  @HttpCode(204)
  export(@Headers('x-original-uri') uri: string): void {
    const url = new URL(uri, 'https://app.norrow.example');
    const signature = url.searchParams.get('signature') ?? '';
    const expires = Number(url.searchParams.get('expires') ?? 0);
    url.searchParams.delete('signature');

    const expected = createHmac('sha256', process.env.APP_KEY ?? '').update(url.toString()).digest('hex');
    const valid = signature.length === expected.length && timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
    if (!valid || expires * 1000 < Date.now()) {
      throw new ForbiddenException();
    }
  }
}
