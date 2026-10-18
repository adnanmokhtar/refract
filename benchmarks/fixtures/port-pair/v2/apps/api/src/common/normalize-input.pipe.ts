import { Injectable, PipeTransform } from '@nestjs/common';

export interface NormalizeOptions {
  trim: boolean;
  emptyToNull: boolean;
  except?: string[];
}

// The V2 equivalent of Laravel's TrimStrings + ConvertEmptyStringsToNull global middleware.
@Injectable()
export class NormalizeInputPipe implements PipeTransform {
  constructor(private readonly options: NormalizeOptions = { trim: true, emptyToNull: true }) {}

  transform(value: unknown): unknown {
    return this.walk(value, undefined);
  }

  private walk(value: unknown, key: string | undefined): unknown {
    if (typeof value === 'string') {
      if (key && this.options.except?.includes(key)) {
        return value;
      }
      const trimmed = this.options.trim ? value.trim() : value;
      return this.options.emptyToNull && trimmed === '' ? null : trimmed;
    }
    if (Array.isArray(value)) {
      return value.map((v) => this.walk(v, key));
    }
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, this.walk(v, k)]));
    }
    return value;
  }
}
