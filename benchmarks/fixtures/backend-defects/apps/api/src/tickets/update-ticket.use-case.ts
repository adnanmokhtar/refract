import { Injectable } from '@nestjs/common';
import { EntityManager, Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { UpdateTicketDto } from './dto/update-ticket.dto';

@Entity({ tableName: 'tickets' })
export class Ticket {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  priority: number = 1;

  @Property({ nullable: false })
  assigneeEmail!: string;
}

@Injectable()
export class UpdateTicketUseCase {
  constructor(private readonly em: EntityManager) {}

  async execute(id: string, dto: UpdateTicketDto): Promise<Ticket> {
    const ticket = await this.em.findOneOrFail(Ticket, { id });
    if (dto.priority !== undefined) ticket.priority = dto.priority;
    if (dto.assigneeEmail !== undefined) ticket.assigneeEmail = dto.assigneeEmail.toLowerCase();
    await this.em.flush();
    return ticket;
  }
}
