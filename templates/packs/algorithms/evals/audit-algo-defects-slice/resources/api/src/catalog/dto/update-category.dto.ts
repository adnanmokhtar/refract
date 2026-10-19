import { IsInt, IsOptional, IsString, IsUUID, Length, Min } from 'class-validator';

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @Length(1, 80)
  name?: string;

  @IsOptional()
  @IsUUID('4')
  parentId?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  position?: number;
}
