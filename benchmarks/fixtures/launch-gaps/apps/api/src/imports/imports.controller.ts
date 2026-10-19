import { Body, Controller, Post, Req } from '@nestjs/common';
import { ImportsService } from './imports.service';

/** Bulk import of products and stock from a spreadsheet (the bulk import extension). */
@Controller('imports')
export class ImportsController {
  constructor(private readonly imports: ImportsService) {}

  @Post()
  start(@Req() req: { user: { tenantId: string } }, @Body() body: { fileId: string; dryRun: boolean }) {
    return this.imports.start(req.user.tenantId, body);
  }
}
