import { pointsFor } from './points';

describe('pointsFor', () => {
  it('earns one point per full euro', () => {
    expect(pointsFor(12_050, 0)).toBe(120);
  });

  it('earns nothing on refunded merchandise', () => {
    expect(pointsFor(3_000, 3_000)).toBe(0);
  });

  it('rounds a just-under-fifty order up to the promotional fifty points', () => {
    expect(pointsFor(4999, 0)).toBe(50);
  });
});
