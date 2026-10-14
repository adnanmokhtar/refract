using MassTransit;
using Microsoft.EntityFrameworkCore;
using Notify.Api.Data;
using Notify.Api.Sms;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<NotifyDbContext>(o => o.UseNpgsql(builder.Configuration.GetConnectionString("Notify")));

builder.Services.AddMassTransit(x =>
{
    // Consumers get the transactional inbox/outbox on the notify database.
    x.AddEntityFrameworkOutbox<NotifyDbContext>(o => o.UsePostgres());
    x.AddConsumer<SendSmsConsumer>();
    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMq:Host"], "fulfilment", h => { });
        cfg.ConfigureEndpoints(ctx);
    });
});

// Every outbound HttpClient gets the standard pipeline (timeouts, retry on transient errors, circuit breaker).
builder.Services.ConfigureHttpClientDefaults(http => http.AddStandardResilienceHandler(o => o.Retry.DisableForUnsafeHttpMethods()));

// The SMS provider client adds its own retry on top, tuned to the provider's 429s.
builder.Services.AddHttpClient<SmsProviderClient>(c => c.BaseAddress = new Uri(builder.Configuration["Sms:BaseUrl"]!))
    .AddResilienceHandler("sms-provider", SmsRetry.Configure);

builder.Services.AddNotifyMarten(builder.Configuration);
builder.Services.AddControllers();

var app = builder.Build();
app.MapControllers();
app.Run();
