import { Body, Controller, ForbiddenException, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateReturnDto, CreateTransferDto, StockTransfersService } from './stock-transfers.service';

@Controller('inventory')
@UseGuards(JwtAuthGuard)
export class InventoryController {
  constructor(private readonly stock: StockTransfersService) {}

  @Post('transfers')
  dispatch(@Req() req: { user: AuthUser }, @Body() body: CreateTransferDto) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.stock.dispatch(req.user.sub, body);
  }

  @Post('transfers/:id/receive')
  receive(@Req() req: { user: AuthUser }, @Param('id', ParseUUIDPipe) id: string) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.stock.receive(req.user.sub, id);
  }

  @Post('returns')
  restock(@Req() req: { user: AuthUser }, @Body() body: CreateReturnDto) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.stock.restock(req.user.sub, body);
  }
}
