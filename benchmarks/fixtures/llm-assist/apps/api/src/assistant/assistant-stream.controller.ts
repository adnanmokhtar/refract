import { Body, Controller, Param, Post, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AuthedRequest } from '../common/authed-request';
import { AssistantStreamService } from './assistant-stream.service';

@Controller('conversations')
export class AssistantStreamController {
  constructor(private readonly streams: AssistantStreamService) {}

  @Post(':conversationId/stream')
  async stream(
    @Param('conversationId') conversationId: string,
    @Body() body: { text: string },
    @Req() req: AuthedRequest,
    @Res() res: Response,
  ): Promise<void> {
    res.setHeader('content-type', 'text/event-stream');
    res.setHeader('cache-control', 'no-cache');
    for await (const text of this.streams.run(conversationId, body.text, req.user)) {
      res.write(`data: ${JSON.stringify({ text })}\n\n`);
    }
    res.end();
  }
}
