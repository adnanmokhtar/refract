import { Controller, Get, Req } from '@nestjs/common';
import { Request } from 'express';
import * as serialize from 'node-serialize';
import { PrismaService } from '../prisma/prisma.service';

interface CookieCart {
  items: { productId: string; quantity: number }[];
}

// Anonymous carts live in the mk_cart cookie until the buyer signs in, at which point the
// web client merges them into the account cart.
@Controller('cart')
export class CartController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async restore(@Req() req: Request) {
    const raw = req.cookies?.mk_cart;
    if (!raw) return { items: [] };

    const cart = serialize.unserialize(Buffer.from(raw, 'base64').toString('utf8')) as CookieCart;
    const ids = (cart.items ?? []).map((i) => i.productId);
    const products = await this.prisma.product.findMany({
      where: { id: { in: ids }, status: 'PUBLISHED' },
      select: { id: true, title: true, priceCents: true, thumbnailUrl: true },
    });

    return {
      items: products.map((p) => ({
        ...p,
        quantity: cart.items.find((i) => i.productId === p.id)?.quantity ?? 1,
      })),
    };
  }
}
