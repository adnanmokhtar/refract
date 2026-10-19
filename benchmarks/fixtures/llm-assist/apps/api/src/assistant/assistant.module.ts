import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { AnswerCache } from './answer-cache';
import { AssistantStreamController } from './assistant-stream.controller';
import { AssistantStreamService } from './assistant-stream.service';
import { AssistantController } from './assistant.controller';
import { AssistantUseCase } from './assistant.use-case';
import { ConversationHistory } from './conversation-history';
import { PromptGuard } from './guard';
import { MemoryService } from './memory.service';
import { SystemPromptBuilder } from './system-prompt';
import { AssistantTools } from './tools';

@Module({
  imports: [BillingModule],
  controllers: [AssistantController, AssistantStreamController],
  providers: [
    AssistantUseCase,
    AssistantStreamService,
    AssistantTools,
    ConversationHistory,
    MemoryService,
    PromptGuard,
    SystemPromptBuilder,
    AnswerCache,
  ],
  exports: [AnswerCache],
})
export class AssistantModule {}
