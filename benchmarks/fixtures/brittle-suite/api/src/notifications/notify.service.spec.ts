import { NotifyService } from './notify.service';
import { Mailer } from './mailer.port';

describe('NotifyService.refundApproved', () => {
  it('emails the shopper the approved amount for their order', async () => {
    const mailer: jest.Mocked<Mailer> = { send: jest.fn().mockResolvedValue(undefined) };
    const service = new NotifyService(mailer);

    await service.refundApproved('ana@shop.test', 'R-1042', '23.50 EUR');

    expect(mailer.send).toHaveBeenCalledWith({
      to: 'ana@shop.test',
      template: 'refund-approved',
      vars: { orderNumber: 'R-1042', amount: '23.50 EUR' },
    });
  });
});
