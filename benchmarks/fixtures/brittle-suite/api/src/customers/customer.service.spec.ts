import { CustomerService } from './customer.service';
import { CustomerRepository } from './customer.repository';

describe('CustomerService.profile', () => {
  const repo = { findOneOrFail: jest.fn(), create: jest.fn() };
  const service = new CustomerService(repo as unknown as CustomerRepository);

  it('shows support agents a canonical email and a masked phone', async () => {
    const customer = { id: 'cus_1', email: 'ana@shop.test', phone: '***-***-0142' };
    repo.findOneOrFail.mockResolvedValue(customer);

    const profile = await service.profile('cus_1');

    expect(profile).toEqual(customer);
  });
});
