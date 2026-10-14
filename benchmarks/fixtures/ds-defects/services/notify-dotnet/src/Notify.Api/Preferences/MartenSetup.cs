using Marten;

namespace Notify.Api.Preferences;

public static class MartenSetup
{
    /// Subscriber preference streams live in Marten's own event store (mt_events, mt_streams) on the notify database.
    public static IServiceCollection AddNotifyMarten(this IServiceCollection services, IConfiguration config)
    {
        services.AddMarten(o =>
        {
            o.Connection(config.GetConnectionString("Notify")!);
            o.DatabaseSchemaName = "notify_events";
        }).UseLightweightSessions();
        return services;
    }
}
