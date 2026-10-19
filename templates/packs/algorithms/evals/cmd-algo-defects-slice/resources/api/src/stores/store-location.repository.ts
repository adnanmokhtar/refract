import { Injectable } from '@nestjs/common';
import { sql } from '@mikro-orm/core';
import { EntityManager } from '@mikro-orm/postgresql';
import { Store } from './store.entity';

export interface PinDrop {
  lat: number;
  lng: number;
}

/** The merchant drops a pin for the store in the console; the pin is stored as the PostGIS point. */
@Injectable()
export class StoreLocationRepository {
  constructor(private readonly em: EntityManager) {}

  async setLocation(storeId: string, pin: PinDrop): Promise<void> {
    const { lat, lng } = pin;
    await this.em.nativeUpdate(Store, { id: storeId }, { location: sql`ST_SetSRID(ST_MakePoint(${lat}, ${lng}), 4326)` } as never);
  }
}
