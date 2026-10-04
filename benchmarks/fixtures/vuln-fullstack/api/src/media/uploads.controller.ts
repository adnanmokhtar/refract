import {
  BadRequestException,
  Controller,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { tmpdir } from 'os';
import { basename } from 'path';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { config } from '../config';
import { ArchiveService } from './archive.service';
import { ThumbnailService } from './thumbnail.service';

const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml'];

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(
    private readonly thumbnails: ThumbnailService,
    private readonly archives: ArchiveService,
  ) {}

  @Post('product-image')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: config.storage.uploads,
        filename: (_req, file, cb) => cb(null, `${Date.now()}-${file.originalname}`),
      }),
      limits: { fileSize: 10 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => cb(null, IMAGE_TYPES.includes(file.mimetype)),
    }),
  )
  async uploadProductImage(
    @UploadedFile() file: Express.Multer.File | undefined,
    @Query('size') size = '640x640',
  ) {
    if (!file) throw new BadRequestException('Expected an image file');
    const thumbnail = await this.thumbnails.resize(file.path, size);
    return { url: `/uploads/${file.filename}`, thumbnail: `/uploads/${basename(thumbnail)}` };
  }

  @Post('product-images.zip')
  @UseInterceptors(
    FileInterceptor('archive', {
      storage: diskStorage({ destination: tmpdir() }),
      limits: { fileSize: 200 * 1024 * 1024 },
    }),
  )
  async uploadArchive(@Req() req: { user: AuthUser }, @UploadedFile() file: Express.Multer.File | undefined) {
    if (!file) throw new BadRequestException('Expected a ZIP archive');
    const written = await this.archives.extractProductImages(file.path, req.user.sub);
    return { files: written.length };
  }
}
