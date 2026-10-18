import moment from 'moment';

export function lastNDays(n: number): { from: string; to: string } {
  const to = moment().endOf('day');
  return { from: to.clone().subtract(n, 'days').startOf('day').toISOString(), to: to.toISOString() };
}
