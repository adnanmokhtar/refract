import { Body, Controller, Post, Req } from '@nestjs/common';
import { AssistantService } from './assistant.service';

/** The AI assistant: answers questions about the merchant's own sales and stock. */
@Controller('assistant')
export class AssistantController {
  constructor(private readonly assistant: AssistantService) {}

  @Post('ask')
  ask(@Req() req: { user: { tenantId: string } }, @Body() body: { question: string }) {
    return this.assistant.ask(req.user.tenantId, body.question);
  }
}
