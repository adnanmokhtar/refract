import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface NearbyStoreRow {
  id: string;
  name: string;
}

const DEFAULT_RADIUS_M = 5000;

/** "Stores near you" on the shopper home screen; only stores listed here can take the order. */
@Injectable()
export class NearbyStoresRepository {
  constructor(private readonly em: EntityManager) {}

  async near(lng: number, lat: number, radiusM = DEFAULT_RADIUS_M): Promise<NearbyStoreRow[]> {
    return this.em.getConnection().execute<NearbyStoreRow[]>(
      `SELECT s.id, s.name
         FROM stores s
        WHERE ST_DWithin(s.location, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)
        ORDER BY s.name`,
      [lng, lat, radiusM],
    );
  }
}
