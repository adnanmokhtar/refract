import { Injectable } from '@nestjs/common';
import { ICommand, ofType, Saga } from '@nestjs/cqrs';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export class ShipmentLostEvent {
  constructor(public readonly orderId: string, public readonly merchantId: string, public readonly amountMinor: number) {}
}

export class RefundShippingFeeCommand {
  constructor(public readonly orderId: string, public readonly merchantId: string, public readonly amountMinor: number) {}
}

/** When a carrier declares a parcel lost, the merchant's shipping fee is refunded. */
@Injectable()
export class LostParcelSagas {
  @Saga()
  shipmentLost = (events$: Observable<unknown>): Observable<ICommand> =>
    events$.pipe(
      ofType(ShipmentLostEvent),
      map((e) => new RefundShippingFeeCommand(e.orderId, e.merchantId, e.amountMinor)),
    );
}
