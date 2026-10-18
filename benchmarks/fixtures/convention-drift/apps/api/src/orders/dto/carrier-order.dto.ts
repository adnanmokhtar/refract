import { Expose } from 'class-transformer';

// Mirrors the carrier's webhook payload, which is snake_case on the wire.
export class CarrierOrderDto {
  @Expose() id!: string;
  @Expose({ name: 'tracking_number' }) tracking_number!: string;
  @Expose({ name: 'created_at' }) created_at!: string;
}
