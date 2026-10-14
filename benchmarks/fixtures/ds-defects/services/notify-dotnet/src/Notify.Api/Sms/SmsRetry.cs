using System.Net;
using Microsoft.Extensions.Http.Resilience;
using Polly;
using Polly.Retry;

namespace Notify.Api.Sms;

public static class SmsRetry
{
    /// The provider throttles at 50 msg/s per account and answers 429 or 503 before accepting a message.
    public static void Configure(ResiliencePipelineBuilder<HttpResponseMessage> pipeline)
    {
        pipeline.AddRetry(new RetryStrategyOptions<HttpResponseMessage>
        {
            MaxRetryAttempts = 4,
            Delay = TimeSpan.FromSeconds(2),
            BackoffType = DelayBackoffType.Constant,
            UseJitter = false,
            ShouldHandle = args => ValueTask.FromResult(
                args.Outcome.Result?.StatusCode is HttpStatusCode.TooManyRequests or HttpStatusCode.ServiceUnavailable),
        });
    }
}
