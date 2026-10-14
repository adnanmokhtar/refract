import { IsDate, IsDecimal, IsISO4217CurrencyCode, IsUUID, MinDate } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateInvoiceDto {
  @IsUUID()
  orderId!: string;

  @IsDecimal({ decimal_digits: '0,2' })
  amountDue!: string;

  @IsISO4217CurrencyCode()
  currency!: string;

  /** The calendar day the invoice falls due (customer's business day). */
  @Type(() => Date)
  @IsDate()
  @MinDate(new Date('2020-01-01'))
  dueDate!: Date;
}
