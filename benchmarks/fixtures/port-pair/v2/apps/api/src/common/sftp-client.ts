import { Injectable } from '@nestjs/common';

@Injectable()
export class SftpClient {
  async put(remotePath: string, contents: string): Promise<void> {
    void remotePath;
    void contents;
  }
}
