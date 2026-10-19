import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  await knex.schema.alterTable('customers', (table) => {
    table.renameColumn('phone_number', 'phone');
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.alterTable('customers', (table) => {
    table.renameColumn('phone', 'phone_number');
  });
}
