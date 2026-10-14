import { ValidateIf, ValidationOptions } from 'class-validator';

/** Absent is allowed; `null` is refused by the validators that follow (unlike @IsOptional). */
export function IsAbsentOr(options?: ValidationOptions): PropertyDecorator {
  return ValidateIf((_obj, value) => value !== undefined, options);
}
