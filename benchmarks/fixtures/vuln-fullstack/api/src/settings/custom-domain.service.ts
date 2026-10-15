import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

const errorText = (e: unknown) => (e instanceof Error ? e.message : String(e));

// Sellers can serve their storefront from their own hostname (`shop.example.com`). The
// hostname is saved from the store settings screen; verification proves the seller controls
// it by fetching a challenge file the seller publishes on that host.
@Injectable()
export class CustomDomainService {
  private readonly logger = new Logger(CustomDomainService.name);

  constructor(private readonly prisma: PrismaService) {}

  async setHostname(sellerId: string, hostname: string) {
    if (!hostname.trim()) throw new BadRequestException('Hostname is required');
    return this.prisma.storeDomain.upsert({
      where: { sellerId },
      create: { sellerId, hostname: hostname.trim(), challenge: randomUUID() },
      update: { hostname: hostname.trim(), verifiedAt: null, lastCheckError: null },
    });
  }

  // POST /api/settings/domain/verify. The settings screen then shows `lastCheckError` from
  // GET /api/settings/domain until the check passes.
  async verify(sellerId: string) {
    const domain = await this.prisma.storeDomain.findUniqueOrThrow({ where: { sellerId } });
    const url = `https://${domain.hostname}/.well-known/marketly-domain.txt`;
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(5_000) });
      const body = (await res.text()).trim();
      const passed = res.ok && body === domain.challenge;
      return this.prisma.storeDomain.update({
        where: { sellerId },
        data: { verifiedAt: passed ? new Date() : null, lastCheckError: passed ? null : `HTTP ${res.status}` },
      });
    } catch (e) {
      return this.prisma.storeDomain.update({
        where: { sellerId },
        data: { verifiedAt: null, lastCheckError: errorText(e) },
      });
    }
  }

  get(sellerId: string) {
    return this.prisma.storeDomain.findUnique({
      where: { sellerId },
      select: { hostname: true, challenge: true, verifiedAt: true, lastCheckError: true },
    });
  }

  // GET /api/settings/domain/dns — the records the seller must add at their registrar,
  // read from the platform's own DNS provider.
  async dnsInstructions(sellerId: string) {
    const domain = await this.prisma.storeDomain.findUniqueOrThrow({ where: { sellerId } });
    const url = `https://dns.marketly.example/v1/zones/storefronts/records?name=${encodeURIComponent(domain.hostname)}`;
    try {
      const res = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(5_000) });
      if (!res.ok) throw new Error(`dns provider answered ${res.status}`);
      return { records: (await res.json()) as unknown[] };
    } catch (e) {
      this.logger.warn(`dns instructions for seller ${sellerId} failed: ${errorText(e)}`);
      await this.prisma.storeDomain.update({
        where: { sellerId },
        data: { lastCheckError: 'DNS_PROVIDER_UNAVAILABLE' },
      });
      return { records: [] };
    }
  }
}
