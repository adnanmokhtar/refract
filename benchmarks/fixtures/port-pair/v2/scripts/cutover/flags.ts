export interface FlagClient {
  set(name: string, value: string): Promise<void>;
  // Flips a write owner behind a fence: pauses the V1 writer pool and revokes its write grants,
  // waits for in-flight V1 transactions to drain, then flips (Figma's PgBouncer pause + revoke).
  setFenced(name: string, value: string, fence: { pauseV1Pool: string; revokeGrants: string[] }): Promise<void>;
}
