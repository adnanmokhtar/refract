import { Injectable } from '@nestjs/common';

/** Persistence and integrations for this feature (bodies elided in this excerpt). */
@Injectable()
export class CatalogService {
  [method: string]: (...args: never[]) => Promise<unknown>;
}
