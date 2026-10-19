import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

interface ZoneEdgeRow {
  from_zone: string;
  to_zone: string;
}

/**
 * Merchants draw delivery zones on the map and mark which zones touch; a courier can hand over between
 * touching zones. Reachability decides whether a store can serve an address at all.
 */
@Injectable()
export class ZoneGraphService {
  constructor(private readonly em: EntityManager) {}

  async reachableZones(storeId: string, fromZone: string): Promise<Set<string>> {
    const edges = await this.em
      .getConnection()
      .execute<ZoneEdgeRow[]>('SELECT from_zone, to_zone FROM zone_edges WHERE store_id = ?', [storeId]);
    const graph = new Map<string, string[]>();
    for (const e of edges) {
      const list = graph.get(e.from_zone);
      if (list) list.push(e.to_zone);
      else graph.set(e.from_zone, [e.to_zone]);
    }

    const seen = new Set<string>([fromZone]);
    const queue: string[] = [fromZone];
    while (queue.length) {
      const zone = queue.shift()!;
      for (const next of graph.get(zone) ?? []) {
        if (!seen.has(next)) {
          seen.add(next);
          queue.push(next);
        }
      }
    }
    return seen;
  }
}
