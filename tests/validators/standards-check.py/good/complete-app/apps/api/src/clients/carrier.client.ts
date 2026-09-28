import { Injectable } from '@nestjs/common';
@Injectable()
export class CarrierClient {
  async track(id: string) {
    const res = await fetch(`https://carrier.example/track/${id}`, { signal: AbortSignal.timeout(5000) });
    return res.json();
  }
}
