import { Controller, Get, Param, Req } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';
import { InboxService } from './inbox.service';

/** WhatsApp inbox. The slug is an extension, so ExtensionModuleGuard judges it. */
@RequireModule('whatsapp_inbox')
@Controller('inbox')
export class InboxController {
  constructor(private readonly inbox: InboxService) {}

  @Get('threads')
  threads(@Req() req: { user: { tenantId: string } }) {
    return this.inbox.threads(req.user.tenantId);
  }

  @Get('threads/:id')
  thread(@Param('id') id: string) {
    return this.inbox.thread(id);
  }
}
