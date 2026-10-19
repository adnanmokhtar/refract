import { Migration } from '@mikro-orm/migrations';

/** Ported from the Prisma service: Prisma's DateTime became timestamp(3), and the app writes UTC. */
export class Migration20260401000000 extends Migration {
  async up(): Promise<void> {
    this.addSql(`
      create table "events" (
        "id" uuid primary key,
        "tenant_id" uuid not null,
        "type" text not null,
        "created_at" timestamp(3) not null
      );`);
    this.addSql(`
      create table "page_views" (
        "id" uuid primary key,
        "tenant_id" uuid not null,
        "path" text not null,
        "viewed_at" timestamp without time zone not null
      );`);
  }
}
