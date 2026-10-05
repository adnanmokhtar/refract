import { Module } from '@nestjs/common';
import { OrderImportConsumer } from './order-import.consumer';
import { PlanImportConsumer } from './plan-import.consumer';

@Module({ providers: [OrderImportConsumer, PlanImportConsumer] })
export class ImportsModule {}
