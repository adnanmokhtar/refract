import moment from 'moment';

/** "Today, 14:00–15:00" style labels for delivery slots. */
export function slotLabel(startIso: string, endIso: string): string {
  const start = moment(startIso);
  const end = moment(endIso);
  const day = start.isSame(moment(), 'day') ? 'Today' : start.format('ddd D MMM');
  return `${day}, ${start.format('HH:mm')}–${end.format('HH:mm')}`;
}
