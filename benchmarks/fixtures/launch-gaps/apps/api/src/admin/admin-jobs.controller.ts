import { Controller, Post } from '@nestjs/common';
import { RequireRole } from '../auth/require-role.decorator';
import { SearchIndexService } from './search-index.service';

/** Operator endpoints, called by the ops CLI (`pnpm ops reindex`), never by the web app. */
@RequireRole('platform-admin')
@Controller('admin/jobs')
export class AdminJobsController {
  constructor(private readonly index: SearchIndexService) {}

  @Post('reindex')
  reindex() {
    return this.index.rebuild();
  }
}
