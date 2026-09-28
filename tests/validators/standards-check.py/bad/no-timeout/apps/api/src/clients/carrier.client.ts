import { Injectable } from '@nestjs/common';
@Injectable()
export class CarrierClient {
  async track(id: string) {
    const res = await fetch(`https://carrier.example/track/${id}`);
    return res.json();
  }
}
