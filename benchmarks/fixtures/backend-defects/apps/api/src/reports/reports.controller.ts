import { Controller, Get, Query, UsePipes, ValidationPipe } from '@nestjs/common';
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

export class SalesReportQuery {
  @IsOptional()
  @IsInt()
  @Min(2020)
  @Max(2100)
  year?: number;

  @IsOptional()
  @IsBoolean()
  includeRefunded?: boolean;
}

@Controller('reports')
@UsePipes(new ValidationPipe({ transform: true, transformOptions: { enableImplicitConversion: true } }))
export class ReportsController {
  @Get('sales')
  async sales(@Query() query: SalesReportQuery): Promise<{ year: number | undefined; includeRefunded: boolean }> {
    return { year: query.year, includeRefunded: query.includeRefunded ?? false };
  }
}
