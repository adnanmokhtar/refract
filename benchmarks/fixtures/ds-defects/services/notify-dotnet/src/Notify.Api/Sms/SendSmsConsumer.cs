using MassTransit;

namespace Notify.Api.Sms;

public record SendSms(Guid MessageId, string To, string Text);

public sealed class SendSmsConsumer(SmsProviderClient sms) : IConsumer<SendSms>
{
    public Task Consume(ConsumeContext<SendSms> context) =>
        sms.SendAsync(context.Message.To, context.Message.Text, context.CancellationToken);
}
