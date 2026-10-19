export class CreateOrderLineDto {
  sku!: string;
  quantity!: number;
  unitPriceMinor!: number;
}

export class CreateOrderDto {
  customerId!: string;
  currency!: string;
  lines!: CreateOrderLineDto[];
}
