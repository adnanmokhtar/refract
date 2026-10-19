import { google } from 'googleapis';
import type { Knex } from 'knex';

/** The merchant pushes its own customer list to its own Google Sheet (merchant-initiated, merchant-owned sheet). */
export async function pushOwnCustomers(knex: Knex, merchantId: string, sheetId: string, auth: unknown) {
  const rows = await knex('customers').where({ merchant_id: merchantId }).select('full_name', 'phone', 'email');
  const sheets = google.sheets({ version: 'v4', auth: auth as never });
  await sheets.spreadsheets.values.update({
    spreadsheetId: sheetId,
    range: 'Customers!A1',
    valueInputOption: 'RAW',
    requestBody: { values: rows.map((r) => [r.full_name, r.phone, r.email]) },
  });
}
