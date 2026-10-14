import { ArrayMaxSize, IsIn, IsObject, IsOptional, IsUrl } from 'class-validator';

export class CreateWebhookSubscriptionDto {
  @IsUrl({ protocols: ['https'], require_protocol: true })
  url!: string;

  @ArrayMaxSize(10)
  @IsIn(['order.paid', 'order.shipped', 'invoice.issued'], { each: true })
  events!: string[];

  /** Free-form labels the merchant attaches; echoed back verbatim, never interpreted. */
  @IsOptional()
  @IsObject()
  metadata?: Record<string, string> | null;
}
