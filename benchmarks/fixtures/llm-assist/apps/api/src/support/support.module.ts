import { Module } from '@nestjs/common';
import { HelpWidgetAnswerService } from './help-widget-answer.service';
import { ReturnIntakeService } from './intake-parse';
import { SimilarTicketsRepository } from './similar-tickets.repository';
import { TicketPriorityService } from './ticket-priority';
import { TicketSummaryController } from './ticket-summary.controller';
import { TicketTagsService } from './ticket-tags.service';

@Module({
  controllers: [TicketSummaryController],
  providers: [TicketPriorityService, TicketTagsService, ReturnIntakeService, HelpWidgetAnswerService, SimilarTicketsRepository],
})
export class SupportModule {}
