@Controller('api/orders')
export class OrdersController {
  @Get()
  index() { return this.orders.list(); }

  @Delete(':order')
  @UseGuards(PermissionsGuard)
  @Permissions('orders.delete')
  destroy(@Param('order') id: string) { return this.orders.remove(id); }
}
