import { IsEmail, IsString, MaxLength } from 'class-validator';
import { IsAbsentOr } from './is-absent-or';

export class UpdateSupplierDto {
  @IsAbsentOr()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsAbsentOr()
  @IsEmail()
  contactEmail?: string;
}
