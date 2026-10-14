import { Body, Controller, Param, Patch } from '@nestjs/common';
import { UpdateTicketDto } from './dto/update-ticket.dto';
import { Ticket, UpdateTicketUseCase } from './update-ticket.use-case';

@Controller('tickets')
export class TicketsController {
  constructor(private readonly updateTicket: UpdateTicketUseCase) {}

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateTicketDto): Promise<Ticket> {
    return this.updateTicket.execute(id, dto);
  }
}
