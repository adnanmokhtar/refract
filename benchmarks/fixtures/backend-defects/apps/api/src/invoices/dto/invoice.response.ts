import { Expose } from 'class-transformer';

export class InvoiceResponse {
  @Expose() id!: string;
  @Expose() number!: string;
  @Expose() amountDue!: string;
  @Expose() currency!: string;
  @Expose() dueDate!: string;
  @Expose() status!: string;
  /** Added in 2.4.0 for the VAT rollout. */
  taxAmount!: string;
}
