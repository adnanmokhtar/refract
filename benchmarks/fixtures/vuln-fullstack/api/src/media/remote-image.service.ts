import { BadRequestException, Injectable } from '@nestjs/common';
import { config } from '../config';

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

@Injectable()
export class RemoteImageService {
  // Product editor: "Add image from URL". The seller pastes a link and we keep a copy so
  // the storefront never hot-links a third-party host.
  async fetchSellerImage(rawUrl: string): Promise<Buffer> {
    const res = await fetch(rawUrl, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new BadRequestException(`Could not fetch image (${res.status})`);
    return this.readImage(res);
  }

  private async readImage(res: Response): Promise<Buffer> {
    const declared = Number(res.headers.get('content-length') ?? 0);
    if (declared > MAX_IMAGE_BYTES) throw new BadRequestException('Image too large');

    const bytes = Buffer.from(await res.arrayBuffer());
    if (bytes.length > MAX_IMAGE_BYTES) throw new BadRequestException('Image too large');

    const png = bytes.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]));
    const jpeg = bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]));
    if (!png && !jpeg) throw new BadRequestException('Only PNG and JPEG images are supported');
    return bytes;
  }

  // Catalogue feed import. Feeds may only reference images on our own CDN hosts.
  async fetchCatalogImage(rawUrl: string): Promise<Buffer> {
    let url: URL;
    try {
      url = new URL(rawUrl);
    } catch {
      throw new BadRequestException('Invalid image URL');
    }
    if (url.protocol !== 'https:' || !config.imageHosts.includes(url.hostname)) {
      throw new BadRequestException('Image host is not allowed');
    }
    const res = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new BadRequestException('Could not fetch catalogue image');
    return this.readImage(res);
  }
}
