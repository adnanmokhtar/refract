import { OnGatewayConnection, OnGatewayDisconnect, WebSocketGateway } from '@nestjs/websockets';
import { IncomingMessage } from 'node:http';
import { WebSocket } from 'ws';
import { PriceEvent, PriceFeed, StockEvent, StockFeed } from './feeds';

interface Subscription {
  productId: string;
  onStock: (event: StockEvent) => void;
}

// Open product pages keep a socket to /ws/products?product=<id> and receive live price and
// stock changes for that product. ~40 k sockets are open at the evening peak; mobile clients
// reconnect every time the app comes back to the foreground.
@WebSocketGateway({ path: '/ws/products' })
export class ProductLiveGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly subscriptions = new Map<WebSocket, Subscription>();

  constructor(
    private readonly priceFeed: PriceFeed,
    private readonly stockFeed: StockFeed,
  ) {}

  handleConnection(client: WebSocket, req: IncomingMessage): void {
    const productId = new URL(req.url ?? '/', 'http://localhost').searchParams.get('product');
    if (!productId) {
      client.close(1008, 'product is required');
      return;
    }

    const listener = (event: PriceEvent) => {
      if (event.productId === productId && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ type: 'price', price: event.price, currency: event.currency }));
      }
    };
    this.priceFeed.on('price', listener);

    const onStock = (event: StockEvent) => {
      if (event.productId === productId && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ type: 'stock', stock: event.stock }));
      }
    };
    this.stockFeed.on('stock', onStock);
    this.subscriptions.set(client, { productId, onStock });
  }

  handleDisconnect(client: WebSocket): void {
    const entry = this.subscriptions.get(client);
    if (!entry) return;
    this.stockFeed.off('stock', entry.onStock);
    this.subscriptions.delete(client);
  }
}
