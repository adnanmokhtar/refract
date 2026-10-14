export class BulkCancelOrdersCommand {
  constructor(public readonly orderIds: string[], public readonly reason: string) {}
}
