import { ToolSpec } from '../llm/llm-gateway.port';

export interface IntakeTool {
  spec: ToolSpec;
  writes: boolean;
  readsThirdPartyText: boolean;
}

/**
 * The intake agent's catalogue for the next model call. Once a tool that returns third-party text
 * (an inbound e-mail, a supplier page) has run in this turn, write tools are withdrawn until the turn ends.
 */
export function catalogueForTurn(all: IntakeTool[], ranThisTurn: Set<string>): ToolSpec[] {
  const tainted = all.some((t) => t.readsThirdPartyText && ranThisTurn.has(t.spec.function.name));
  const allowed = tainted ? all.filter((t) => !t.writes) : all;
  return allowed.map((t) => t.spec);
}
