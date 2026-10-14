import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { DiscoveryService, MetadataScanner } from '@nestjs/core';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CronJob } from 'cron';
import { MERCHANT_CRON_METADATA } from './merchant-cron.decorator';

/**
 * Merchants configure their own export schedules (merchant_schedules table). At boot every api process reads
 * them and registers one cron per schedule, so the console can add one without a deploy.
 */
@Injectable()
export class MerchantCronExplorer implements OnApplicationBootstrap {
  constructor(
    private readonly discovery: DiscoveryService,
    private readonly scanner: MetadataScanner,
    private readonly registry: SchedulerRegistry,
  ) {}

  onApplicationBootstrap(): void {
    for (const wrapper of this.discovery.getProviders()) {
      const instance = wrapper.instance as Record<string, unknown> | undefined;
      if (!instance) continue;
      for (const method of this.scanner.getAllMethodNames(Object.getPrototypeOf(instance))) {
        const cron = Reflect.getMetadata(MERCHANT_CRON_METADATA, (instance as never)[method]) as string | undefined;
        if (!cron) continue;
        const job = new CronJob(cron, () => (instance as never as Record<string, () => Promise<void>>)[method]());
        this.registry.addCronJob(`${wrapper.name}.${method}`, job);
        job.start();
      }
    }
  }
}
