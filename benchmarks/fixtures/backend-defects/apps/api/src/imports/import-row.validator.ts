import { plainToInstance, Type } from 'class-transformer';
import { IsInt, IsString, Max, Min, MaxLength, validate } from 'class-validator';

export class ImportRowDto {
  @IsString({ groups: ['import'] })
  @MaxLength(40, { groups: ['import'] })
  sku!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  priceMinor!: number;
}

export async function validateImportRows(rows: Record<string, string>[]): Promise<string[]> {
  const out: string[] = [];
  for (const [i, row] of rows.entries()) {
    const errors = await validate(plainToInstance(ImportRowDto, row), { groups: ['import'] });
    for (const e of errors) out.push(`row ${i + 1}: ${e.property}`);
  }
  return out;
}
