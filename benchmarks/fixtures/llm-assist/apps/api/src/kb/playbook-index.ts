import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { EmbeddingsClient } from '../llm/embeddings.client';
import { toVector } from './kb-search.repository';

/** Cross-workspace playbooks every assistant may cite ("how to handle a chargeback", ...). */
@Injectable()
export class PlaybookIndex {
  constructor(
    private readonly em: EntityManager,
    private readonly embeddings: EmbeddingsClient,
  ) {}

  async add(doc: { title: string; body: string }): Promise<void> {
    const embedding = await this.embeddings.embed(`${doc.title}\n${doc.body}`);
    await this.em.getConnection().execute(
      'INSERT INTO shared_playbook_chunks (id, title, body, embedding) VALUES (?, ?, ?, ?::vector)',
      [randomUUID(), doc.title, doc.body, toVector(embedding)],
    );
  }
}
