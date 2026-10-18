import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';

// The V2 side of spatie/laravel-activitylog: one activity_log row per audited change.
@Injectable()
export class ActivityService {
  constructor(private readonly em: EntityManager) {}

  log(event: string, subject: { id: number }, properties: Record<string, unknown>, logName = 'default'): void {
    this.em.getConnection().execute(
      'insert into activity_log (log_name, description, subject_id, properties, created_at) values (?, ?, ?, ?, now())',
      [logName, event, subject.id, JSON.stringify(properties)],
    );
  }
}
