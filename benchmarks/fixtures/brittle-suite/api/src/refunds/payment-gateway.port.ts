// The payment provider, behind a port the project owns. The adapter lives in payments/stripe.adapter.ts.
export abstract class PaymentGateway {
  abstract refundCapture(paymentRef: string, amountCents: number): Promise<string>;
}
