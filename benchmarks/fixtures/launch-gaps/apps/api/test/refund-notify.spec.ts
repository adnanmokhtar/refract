import { RefundNotifier } from '../src/orders/refund-notifier';

describe('refund notifications', () => {
  const mailer = { queue: jest.fn() };
  const timeline = { record: jest.fn() };
  const notifier = new RefundNotifier(mailer as never, timeline as never);

  beforeEach(() => jest.resetAllMocks());

  it('AC-010 the confirmation names the refunded amount', async () => {
    await notifier.refundCompleted({ orderId: 'o1', email: 'c@example.com', amountCents: 1250, currency: 'USD' });
    expect(mailer.queue).toHaveBeenCalledWith('refund-confirmation', 'c@example.com', expect.objectContaining({ amount: '$12.50' }));
  });

  it('AC-011 the merchant is told when a refund fails', async () => {
    await notifier.refundFailed({ orderId: 'o1', merchantEmail: 'm@example.com', reason: 'card_expired' });
    expect(mailer.queue).toHaveBeenCalledWith('refund-failed', 'm@example.com', expect.anything());
  });

  it('AC-012 a rejected send is retried three times and recorded', async () => {
    mailer.queue.mockRejectedValue(new Error('rejected'));
    await notifier.refundCompleted({ orderId: 'o1', email: 'c@example.com', amountCents: 100, currency: 'USD' });
    expect(mailer.queue).toHaveBeenCalledTimes(3);
    expect(timeline.record).toHaveBeenCalledWith('o1', 'refund_email_failed');
  });
});
