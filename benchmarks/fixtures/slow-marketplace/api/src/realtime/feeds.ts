import { Injectable, OnModuleInit } from '@nestjs/common';
import { EventEmitter } from 'node:events';
import Redis from 'ioredis';

export interface PriceEvent {
  productId: string;
  price: number;
  currency: string;
}

export interface StockEvent {
  productId: string;
  stock: number;
}

// Fan-in of the "prices" and "stock" Redis channels into in-process emitters. Every open
// product page subscribes, so the listener cap is lifted.
@Injectable()
export class PriceFeed extends EventEmitter implements OnModuleInit {
  constructor() {
    super();
    this.setMaxListeners(0);
  }

  async onModuleInit() {
    const sub = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await sub.subscribe('prices');
    sub.on('message', (_channel, message) => this.emit('price', JSON.parse(message) as PriceEvent));
  }
}

@Injectable()
export class StockFeed extends EventEmitter implements OnModuleInit {
  constructor() {
    super();
    this.setMaxListeners(0);
  }

  async onModuleInit() {
    const sub = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await sub.subscribe('stock');
    sub.on('message', (_channel, message) => this.emit('stock', JSON.parse(message) as StockEvent));
  }
}
