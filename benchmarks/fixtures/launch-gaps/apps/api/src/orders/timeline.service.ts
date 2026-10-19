import { Injectable } from '@nestjs/common';

@Injectable()
export class TimelineService {
  async record(orderId: string, kind: string): Promise<void> {
    void orderId;
    void kind;
  }
}
