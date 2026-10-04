import { Injectable, Logger } from '@nestjs/common';
import { createWriteStream } from 'fs';
import { mkdir, rm } from 'fs/promises';
import { dirname, join } from 'path';
import { pipeline } from 'stream/promises';
import * as unzipper from 'unzipper';
import { config } from '../config';

const MAX_ENTRIES = 2_000;

@Injectable()
export class ArchiveService {
  private readonly logger = new Logger(ArchiveService.name);

  // Bulk image import: sellers upload one ZIP of product photos named by SKU, e.g.
  // "SKU-1042/front.jpg". Files are unpacked under the seller's upload folder.
  async extractProductImages(zipPath: string, sellerId: string): Promise<string[]> {
    const dest = join(config.storage.uploads, sellerId, 'bulk');
    await mkdir(dest, { recursive: true });

    const archive = await unzipper.Open.file(zipPath);
    if (archive.files.length > MAX_ENTRIES) throw new Error('Too many files in archive');

    const written: string[] = [];
    for (const entry of archive.files) {
      if (entry.type !== 'File') continue;
      const target = join(dest, entry.path);
      await mkdir(dirname(target), { recursive: true });
      await pipeline(entry.stream(), createWriteStream(target));
      written.push(target);
    }

    await rm(zipPath, { force: true });
    this.logger.log(`bulk import seller=${sellerId} files=${written.length}`);
    return written;
  }
}
