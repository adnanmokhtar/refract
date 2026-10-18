@Controller('api/orders')
export class OrdersController {
  @Get()
  @UseGuards(PermissionsGuard)
  index() { return this.orders.list(); }

  @Delete(':order')
  destroy(@Param('order') id: string) { return this.orders.remove(id); }
}
