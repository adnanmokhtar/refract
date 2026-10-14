import { IsDecimal, IsISO4217CurrencyCode, IsUUID } from 'class-validator';

export class CapturePaymentDto {
  @IsUUID()
  orderId!: string;

  @IsDecimal({ decimal_digits: '0,3' })
  amount!: string;

  @IsISO4217CurrencyCode()
  currency!: string;
}
