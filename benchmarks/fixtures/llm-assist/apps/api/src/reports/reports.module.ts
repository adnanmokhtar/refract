import { Module } from '@nestjs/common';
import { FormulaService } from './formula.service';
import { ReportNarrativeService } from './report-narrative.service';

@Module({ providers: [ReportNarrativeService, FormulaService], exports: [ReportNarrativeService, FormulaService] })
export class ReportsModule {}
