import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/** Appends to a return's stream at the version after the one the caller read. */
export async function appendReturnEvent(streamId: string, readVersion: number, type: string, data: object): Promise<void> {
  await prisma.returnEvent.create({ data: { streamId, version: readVersion + 1, type, data } });
}

export async function readReturnStream(streamId: string): Promise<Array<{ version: number; type: string; data: unknown }>> {
  return prisma.returnEvent.findMany({ where: { streamId }, orderBy: { version: 'asc' }, select: { version: true, type: true, data: true } });
}
