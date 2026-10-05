import { hasStamps, stampsUntilReward } from './points-counter';

describe('hasStamps', () => {
  it('is false for a new card', () => {
    expect(hasStamps({ stamps: [] })).toBe(false);
  });

  it('is true once a stamp is collected', () => {
    expect(hasStamps({ stamps: ['ord_1', 'ord_2', 'ord_3'] })).toBe(true);
  });
});

describe('stampsUntilReward', () => {
  it('counts down to the reward', () => {
    expect(stampsUntilReward({ stamps: ['ord_1', 'ord_2'] })).toBe(8);
  });

  it('never goes below zero', () => {
    expect(stampsUntilReward({ stamps: Array.from({ length: 12 }, (_, i) => `ord_${i}`) })).toBe(0);
  });
});
