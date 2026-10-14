import { ArrayMaxSize, IsDecimal, IsString, MaxLength } from 'class-validator';

export class CreateProductDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @IsDecimal({ decimal_digits: '0,2' })
  price!: string;

  @IsString()
  @ArrayMaxSize(20)
  tags!: string[];
}
