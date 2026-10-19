import {
  BadGatewayException,
  Body,
  Controller,
  Headers,
  HttpCode,
  Param,
  Post,
  UnsupportedMediaTypeException,
  UseGuards,
} from '@nestjs/common';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { createGunzip, gunzipSync } from 'node:zlib';
import { StoreStaffGuard } from '../stores/store-staff.guard';
import { FeedImportService } from './feed-import.service';

@Controller('stores/:storeId/feeds')
@UseGuards(StoreStaffGuard)
export class FeedUploadController {
  constructor(private readonly feeds: FeedImportService) {}

  // POST /stores/:storeId/feeds — a seller's ERP pushes its product feed as gzipped XML
  // (application/gzip, up to 50 MB compressed). Larger sellers push every 15 minutes.
  @Post()
  @HttpCode(202)
  async upload(
    @Param('storeId') storeId: string,
    @Headers('content-type') contentType: string,
    @Body() body: Buffer,
  ): Promise<{ accepted: number }> {
    if (contentType !== 'application/gzip') throw new UnsupportedMediaTypeException('send application/gzip');
    const xml = gunzipSync(body).toString('utf8');
    const accepted = await this.feeds.importXml(storeId, xml);
    return { accepted };
  }

  // POST /stores/:storeId/feeds/pull — fetch the feed from the URL the seller registered
  // (and verified) in the dashboard, instead of waiting for a push.
  @Post('pull')
  @HttpCode(202)
  async pull(@Param('storeId') storeId: string): Promise<{ accepted: number }> {
    const url = await this.feeds.registeredFeedUrl(storeId);
    const res = await fetch(url, { signal: AbortSignal.timeout(60_000) });
    if (!res.ok || !res.body) throw new BadGatewayException(`feed fetch failed with ${res.status}`);

    const sink = this.feeds.streamingParser(storeId);
    await pipeline(
      Readable.fromWeb(res.body as unknown as import('node:stream/web').ReadableStream),
      createGunzip(),
      sink,
    );
    return { accepted: sink.count };
  }
}
