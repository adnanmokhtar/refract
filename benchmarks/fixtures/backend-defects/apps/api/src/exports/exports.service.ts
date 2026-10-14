import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';

export interface ExportJob {
  id: string;
  status: 'queued' | 'running' | 'ready' | 'failed';
}

@Injectable()
export class ExportsService {
  constructor(private readonly em: EntityManager) {}

  async find(id: string): Promise<ExportJob> {
    const [row] = await this.em.getConnection().execute('select id, status from export_jobs where id = ?', [id]);
    return row as ExportJob;
  }

  async csv(id: string): Promise<string> {
    return `id\n${id}\n`;
  }
}
