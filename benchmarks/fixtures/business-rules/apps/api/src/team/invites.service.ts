import { Injectable } from '@nestjs/common';

@Injectable()
export class InvitesService {
  async pending() { return []; }
  async invite(email: string, role: string) { return { email, role }; }
  async byToken(token: string): Promise<{ id: string } | null> { return null; }
  async accept(invite: { id: string }) { return invite; }
}
