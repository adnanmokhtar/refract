import { IsString, MaxLength } from 'class-validator';

export class SearchCustomersDto {
  @IsString()
  @MaxLength(80)
  q!: string;
}
