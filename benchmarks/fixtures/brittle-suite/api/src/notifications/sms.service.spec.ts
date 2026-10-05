import { SmsGateway, SmsMessage, SmsService } from './sms.service';

const sent: SmsMessage[] = [];

class RecordingGateway extends SmsGateway {
  async deliver(message: SmsMessage): Promise<void> {
    sent.push(message);
  }
}

describe('SmsService.pickupBooked', () => {
  it('texts the shopper the pickup window', async () => {
    const service = new SmsService(new RecordingGateway());
    await service.pickupBooked('ret_1', '+4915123456789', 'Tue 10:00-12:00');
    expect(sent).toHaveLength(1);
    expect(sent[0].body).toContain('Tue 10:00-12:00');
  });

  it('sends one text for a repeated booking of the same return', async () => {
    const service = new SmsService(new RecordingGateway());
    await service.pickupBooked('ret_2', '+4915123456789', 'Wed 14:00-16:00');
    await service.pickupBooked('ret_2', '+4915123456789', 'Wed 14:00-16:00');
    expect(sent).toHaveLength(2);
  });
});
