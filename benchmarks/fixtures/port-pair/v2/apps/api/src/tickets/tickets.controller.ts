import { Controller, Get, HttpCode, Param, Patch, Post, UsePipes } from '@nestjs/common';
import { CreateTicketBody, type CreateTicketBodyT, TicketListQuery, type TicketListQueryT, UpdateTicketBody, type UpdateTicketBodyT } from '@norrow/contracts';
import { type AuthUser, CurrentUser } from '../common/current-user.decorator';
import { NormalizeInputPipe } from '../common/normalize-input.pipe';
import { Roles } from '../common/roles.decorator';
import { ZodBody, ZodQuery } from '../common/zod';
import { TicketsService } from './tickets.service';

// Ticket text comes from the portal form and the mobile app: trim and empty → null, as V1's
// global TrimStrings and ConvertEmptyStringsToNull did.
@Controller('tickets')
@UsePipes(new NormalizeInputPipe({ trim: true, emptyToNull: true }))
export class TicketsController {
  constructor(private readonly tickets: TicketsService) {}

  @Get()
  list(@ZodQuery(TicketListQuery) query: TicketListQueryT) {
    return this.tickets.list(query);
  }

  @Post()
  @HttpCode(201)
  create(@ZodBody(CreateTicketBody) body: CreateTicketBodyT, @CurrentUser() user: AuthUser) {
    return this.tickets.create(body, user);
  }

  @Post('next')
  @Roles('agent', 'admin')
  @HttpCode(200)
  next(@CurrentUser() user: AuthUser) {
    return this.tickets.assignNext(user);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.tickets.get(id);
  }

  @Patch(':id')
  @Roles('admin')
  update(@Param('id') id: string, @ZodBody(UpdateTicketBody) body: UpdateTicketBodyT) {
    return this.tickets.update(id, body);
  }

  @Post(':id/reopen')
  @HttpCode(200)
  reopen(@Param('id') id: string) {
    return this.tickets.reopen(id);
  }
}
