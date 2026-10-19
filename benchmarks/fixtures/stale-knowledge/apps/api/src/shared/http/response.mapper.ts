import { Injectable } from '@nestjs/common';

export interface Identified {
  id: string;
}

@Injectable()
export class ResponseMapper {
  toResponse<T extends Identified>(entity: T): T & { href: string } {
    return { ...entity, href: `/api/${entity.id}` };
  }
}
