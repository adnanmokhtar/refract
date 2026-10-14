import { Controller, HttpCode, Param, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

@Controller('orders/:orderId/attachments')
export class AttachmentsController {
  /** Customer uploads a photo of a damaged item. */
  @Post()
  @HttpCode(201)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async attach(@Param('orderId') orderId: string, @UploadedFile() file: { originalname: string; size: number }): Promise<{ orderId: string; name: string }> {
    return { orderId, name: file.originalname };
  }
}
