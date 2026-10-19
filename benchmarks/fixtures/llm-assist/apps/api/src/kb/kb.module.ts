import { Module } from '@nestjs/common';
import { AssistantModule } from '../assistant/assistant.module';
import { KbAnswerService } from './kb-answer.service';
import { KbArticlesService } from './kb-articles.service';
import { KbIngestService } from './kb-ingest.service';
import { KbReindexController } from './kb-reindex.controller';
import { KbSearchController } from './kb-search.controller';
import { KbSearchRepository } from './kb-search.repository';
import { KbUploadController } from './kb-upload.controller';
import { PlaybookIndex } from './playbook-index';

@Module({
  imports: [AssistantModule],
  controllers: [KbSearchController, KbUploadController, KbReindexController],
  providers: [KbSearchRepository, KbAnswerService, KbArticlesService, KbIngestService, PlaybookIndex],
})
export class KbModule {}
