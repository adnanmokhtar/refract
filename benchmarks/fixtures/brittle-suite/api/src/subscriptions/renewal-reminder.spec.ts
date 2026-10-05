import { systemClock } from '../shared/clock';
import { dueForReminder } from './renewal-reminder';

jest.mock('../shared/clock', () => ({
  systemClock: { now: jest.fn(() => new Date('2026-02-25T09:00:00Z')) },
}));

describe('dueForReminder', () => {
  const members = [
    { memberId: 'm_1', renewsOn: '2026-03-04' },
    { memberId: 'm_2', renewsOn: '2026-03-05' },
  ];

  it('picks the memberships that renew in seven days, across a month end', () => {
    expect(dueForReminder(members).map((m) => m.memberId)).toEqual(['m_1']);
  });

  it('reads the pinned clock', () => {
    dueForReminder(members);
    expect(systemClock.now).toHaveBeenCalled();
  });
});
