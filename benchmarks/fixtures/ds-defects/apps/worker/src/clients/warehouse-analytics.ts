import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class Warehouse {
  async insertOrder(row: { orderId: string; merchantId: string; placedAt: string }): Promise<void> {
    await request(`${process.env.CLICKHOUSE_URL}/?query=INSERT%20INTO%20orders%20FORMAT%20JSONEachRow`, { method: 'POST', body: JSON.stringify(row) });
  }
}
