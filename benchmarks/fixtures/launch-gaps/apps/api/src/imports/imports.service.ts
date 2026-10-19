import { Injectable } from '@nestjs/common';

/** Persistence and integrations for this feature (bodies elided in this excerpt). */
@Injectable()
export class ImportsService {
  [method: string]: (...args: never[]) => Promise<unknown>;
}
