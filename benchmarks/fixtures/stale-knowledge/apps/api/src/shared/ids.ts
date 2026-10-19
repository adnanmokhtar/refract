import { uuidv7 } from 'uuidv7';

/** Primary keys: time-ordered UUIDv7 strings, generated in the entity constructor. */
export const newId = (): string => uuidv7();
