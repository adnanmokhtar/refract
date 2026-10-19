import { createHash, randomBytes } from 'node:crypto';
import type Redis from 'ioredis';

interface Pending {
  tool: string;
  argsHash: string;
  actorId: string;
  turn: number;
}

const hashArgs = (args: unknown) => createHash('sha256').update(JSON.stringify(args)).digest('hex');

/**
 * A write the intake agent proposes is held until the human clicks "Confirm" in the UI. The token is
 * shown to the human only, never to the model, and is bound to the tool, its arguments, the actor and
 * the turn that proposed it; it is consumed in a later turn or not at all.
 */
export class ConfirmationStore {
  constructor(private readonly redis: Redis) {}

  async propose(tool: string, args: unknown, actorId: string, turn: number): Promise<string> {
    const token = randomBytes(18).toString('base64url');
    const pending: Pending = { tool, argsHash: hashArgs(args), actorId, turn };
    await this.redis.set(`confirm:${token}`, JSON.stringify(pending), 'EX', 900);
    return token;
  }

  async consume(token: string, tool: string, args: unknown, actorId: string, currentTurn: number): Promise<boolean> {
    const raw = await this.redis.getdel(`confirm:${token}`);
    if (!raw) return false;
    const p: Pending = JSON.parse(raw);
    return p.tool === tool && p.argsHash === hashArgs(args) && p.actorId === actorId && p.turn < currentTurn;
  }
}
