import { Controller, Param, Post } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { CartsService } from './carts.service';

@Controller('carts')
export class CartsController {
  constructor(private readonly carts: CartsService) {}

  /** Re-checks stock and prices before checkout; creates nothing. */
  @Post(':id/validate')
  async validate(@CurrentUser() user: Principal, @Param('id') id: string): Promise<{ ok: boolean; problems: string[] }> {
    return this.carts.validate(user, id);
  }
}
