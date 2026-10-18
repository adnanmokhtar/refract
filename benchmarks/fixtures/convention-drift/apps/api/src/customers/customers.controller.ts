import { Controller, Get, Query } from '@nestjs/common';
import { CustomersService } from './customers.service';

@Controller('customers')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  @Get()
  list(@Query('page') page = '1', @Query('size') size = '20') {
    return this.customers.list(Number(page), Number(size));
  }
}
