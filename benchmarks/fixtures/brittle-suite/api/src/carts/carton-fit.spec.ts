import { CARTONS, CartonOverflowError, fit, planCarton } from './carton-fit';

describe('planCarton', () => {
  it('packs two mugs into the small carton', () => {
    const plan = planCarton([2_100, 2_100]);
    fit(plan, CARTONS.small);
    expect(plan).toEqual({ carton: 'small', volumeCm3: 4_200 });
  });

  it('moves up to the medium carton when the small one is full', () => {
    expect(planCarton([4_000, 4_000]).carton).toBe('medium');
  });

  it('refuses a return larger than the large carton', () => {
    expect(() => planCarton([30_000, 30_000])).toThrow(CartonOverflowError);
  });
});
