import { BadRequestException, Injectable } from '@nestjs/common';
import { execFile } from 'child_process';
import { randomUUID } from 'crypto';
import { mkdir, readFile } from 'fs/promises';
import { dirname, join } from 'path';
import { promisify } from 'util';
import { config } from '../config';
import { PrismaService } from '../prisma/prisma.service';

const runFile = promisify(execFile);

@Injectable()
export class ThemesService {
  constructor(private readonly prisma: PrismaService) {}

  list(sellerId: string) {
    return this.prisma.theme.findMany({ where: { sellerId }, orderBy: { createdAt: 'desc' } });
  }

  // Sellers can install a storefront theme straight from a public git repository,
  // optionally pinned to a branch or tag.
  async installFromGit(sellerId: string, repoUrl: string, ref = 'main') {
    if (!repoUrl) throw new BadRequestException('Repository URL is required');
    const dest = join(config.storage.themes, sellerId, randomUUID());
    await mkdir(dirname(dest), { recursive: true });

    await runFile('git', ['clone', '--depth', '1', '--branch', ref, repoUrl, dest], { timeout: 120_000 });

    const manifest = JSON.parse(await readFile(join(dest, 'theme.json'), 'utf8'));
    return this.prisma.theme.create({
      data: { sellerId, name: String(manifest.name ?? 'Untitled theme'), path: dest, source: repoUrl },
    });
  }
}
