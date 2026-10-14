import { IsUUID } from 'class-validator';

export class ApplyRateCardDto {
  @IsUUID()
  rateCardId!: string;

  @IsUUID()
  orderId!: string;
}
