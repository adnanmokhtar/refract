import { Injectable } from '@nestjs/common';

// The one place the API reads the wall clock, so tests can pin it.
@Injectable()
export class Clock {
  now(): Date {
    return new Date();
  }
}

export const systemClock = new Clock();
