import { Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SessionGuard } from '../common/session.guard';
import { PlaybookIndex } from './playbook-index';

/** Any signed-in agent can share a playbook document with the community library. */
@Controller('kb/playbooks')
@UseGuards(SessionGuard)
export class KbUploadController {
  constructor(private readonly playbooks: PlaybookIndex) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 2 * 1024 * 1024 } }))
  async upload(@UploadedFile() file: { originalname: string; buffer: Buffer }) {
    const body = file.buffer.toString('utf8');
    await this.playbooks.add({ title: file.originalname, body });
    return { ok: true };
  }
}
