import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { OUTBOX_PORT, OutboxPort } from '../outbox/outbox.port';
import { TxRunner } from '../outbox/tx-runner';
import { Manifest } from './manifest.entity';

@Injectable()
export class CloseManifest {
  constructor(
    private readonly tx: TxRunner,
    private readonly em: EntityManager,
    @Inject(OUTBOX_PORT) private readonly outbox: OutboxPort,
  ) {}

  async execute(manifestId: string): Promise<void> {
    await this.tx.run(async () => {
      const manifest = await this.em.findOneOrFail(Manifest, manifestId);
      manifest.close();
      await this.em.flush();
      await this.outbox.emit('manifest.closed', { manifestId, parcels: manifest.parcelCount }, manifest.id);
    });
  }
}
