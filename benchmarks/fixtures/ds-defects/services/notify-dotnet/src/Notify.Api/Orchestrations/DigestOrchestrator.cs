using Microsoft.Azure.Functions.Worker;
using Microsoft.DurableTask;

namespace Notify.Api.Orchestrations;

/// Weekly digest fan-out for merchants (Durable Functions, isolated worker).
public static class DigestOrchestrator
{
    [Function(nameof(DigestOrchestrator))]
    public static async Task Run([OrchestrationTrigger] TaskOrchestrationContext context)
    {
        var week = context.CurrentUtcDateTime.Date;
        var merchants = await context.CallActivityAsync<List<string>>(nameof(ListMerchants), week);
        var sends = merchants.Select(m => context.CallActivityAsync(nameof(SendDigest), m));
        await Task.WhenAll(sends);
    }

    [Function(nameof(ListMerchants))]
    public static Task<List<string>> ListMerchants([ActivityTrigger] DateTime week) => Task.FromResult(new List<string>());

    [Function(nameof(SendDigest))]
    public static Task SendDigest([ActivityTrigger] string merchantId) => Task.CompletedTask;
}
