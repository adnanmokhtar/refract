import { trialDaysLeft } from './trial';

describe('trialDaysLeft', () => {
  it('counts the days left in a trial started five days ago', () => {
    jest.spyOn(Date, 'now').mockReturnValue(Date.UTC(2026, 0, 15, 12));
    expect(trialDaysLeft({ startedAt: Date.UTC(2026, 0, 10, 12) })).toBe(9);
  });

  it('counts down a trial started a week ago', () => {
    expect(trialDaysLeft({ startedAt: Date.UTC(2026, 0, 8, 12) })).toBe(7);
  });

  it('never goes below zero', () => {
    expect(trialDaysLeft({ startedAt: Date.UTC(2025, 11, 1) })).toBe(0);
  });
});
