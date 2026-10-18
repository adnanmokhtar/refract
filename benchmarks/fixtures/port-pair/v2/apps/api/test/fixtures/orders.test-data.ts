// Recorded V1 payloads used by the unit tests of the backfill mappers. The strings are V1's
// stored vocabulary on purpose: the mapper under test is what turns them into V2 values.
export const v1OrderRows = [
  { id: 101, number: 'SO-0000101', status: 'placed', currency: 'SAR', total_amount: '120.50' },
  { id: 102, number: 'SO-0000102', status: 'cancelled', currency: 'SAR', total_amount: '0.00' },
  { id: 103, number: 'SO-0000103', status: 'refunded', currency: 'AED', total_amount: '-35.00' },
];

export const v1TicketRows = [
  { id: 41, subject: 'Damaged carton', priority: 4, status: 'open' },
  { id: 42, subject: 'Wrong invoice address', priority: 1, status: 'closed' },
];
