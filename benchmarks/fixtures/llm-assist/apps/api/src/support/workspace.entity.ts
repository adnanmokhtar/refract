import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'workspaces' })
export class Workspace {
  @PrimaryKey() id!: string;
  @Property() name!: string;
  @Property() plan!: 'starter' | 'team' | 'business';
}
