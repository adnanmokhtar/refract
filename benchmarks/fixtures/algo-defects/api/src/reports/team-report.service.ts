import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface TeamRow {
  id: string;
  name: string;
}

export interface MemberRow {
  id: string;
  teamId: string;
  displayName: string;
  picksToday: number;
}

/** Merchant "teams" report: each picking team with its members and today's picks. */
@Injectable()
export class TeamReportService {
  constructor(private readonly em: EntityManager) {}

  async teamsWithMembers(tenantId: string) {
    const conn = this.em.getConnection();
    const teams = await conn.execute<TeamRow[]>('SELECT id, name FROM teams WHERE tenant_id = ?', [tenantId]);
    const members = await conn.execute<MemberRow[]>(
      'SELECT id, team_id AS "teamId", display_name AS "displayName", picks_today AS "picksToday" FROM team_members WHERE tenant_id = ?',
      [tenantId],
    );
    return teams.map((t) => ({ ...t, members: members.filter((m) => m.teamId === t.id) }));
  }
}
