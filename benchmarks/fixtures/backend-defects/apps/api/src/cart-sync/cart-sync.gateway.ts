import { MessageBody, SubscribeMessage, WebSocketGateway } from '@nestjs/websockets';
import { IsInt, IsUUID, Max, Min } from 'class-validator';

export class CartUpdateDto {
  @IsUUID()
  cartId!: string;

  @IsUUID()
  productId!: string;

  @IsInt()
  @Min(0)
  @Max(99)
  quantity!: number;
}

/** Live cart updates from the storefront (browser WebSocket). */
@WebSocketGateway({ namespace: '/cart' })
export class CartSyncGateway {
  @SubscribeMessage('cart.update')
  async handleUpdate(@MessageBody() dto: CartUpdateDto): Promise<{ ok: boolean }> {
    return { ok: dto.quantity >= 0 };
  }
}
