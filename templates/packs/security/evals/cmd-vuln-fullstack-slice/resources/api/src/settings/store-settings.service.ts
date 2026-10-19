import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface StoreSettings {
  theme: { primaryColor: string; logoUrl?: string };
  checkout: { guestCheckout: boolean; minOrderCents: number };
  notifications: { orderEmail: boolean; lowStockEmail: boolean };
}

const DEFAULT_SETTINGS: StoreSettings = {
  theme: { primaryColor: '#1f6feb' },
  checkout: { guestCheckout: false, minOrderCents: 0 },
  notifications: { orderEmail: true, lowStockEmail: false },
};

@Injectable()
export class StoreSettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async get(sellerId: string): Promise<StoreSettings> {
    const row = await this.prisma.storeSettings.findUnique({ where: { sellerId } });
    return structuredClone({ ...DEFAULT_SETTINGS, ...((row?.data as object) ?? {}) }) as StoreSettings;
  }

  // The settings screen PATCHes only the section it edited, e.g.
  //   { "checkout": { "guestCheckout": true } }
  // so the patch is merged into the stored document instead of replacing it.
  async patch(sellerId: string, patch: Record<string, unknown>) {
    const merged = this.merge(await this.get(sellerId), patch);
    const data = merged as unknown as Prisma.InputJsonObject;
    await this.prisma.storeSettings.upsert({
      where: { sellerId },
      create: { sellerId, data },
      update: { data },
    });
    return merged;
  }

  private merge(target: any, source: any): any {
    for (const key of Object.keys(source)) {
      const value = source[key];
      if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
        if (typeof target[key] !== 'object' || target[key] === null) target[key] = {};
        this.merge(target[key], value);
      } else {
        target[key] = value;
      }
    }
    return target;
  }
}
