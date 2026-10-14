using Marten;

namespace Notify.Api.Preferences;

public record PreferenceChanged(Guid SubscriberId, string Channel, bool Enabled);

public sealed class SubscriberPreferences
{
    public Guid Id { get; set; }
    public HashSet<string> OptedOut { get; } = new();

    public bool IsOptedOut(string channel) => OptedOut.Contains(channel);

    public void Apply(PreferenceChanged e)
    {
        if (e.Enabled) OptedOut.Remove(e.Channel); else OptedOut.Add(e.Channel);
    }
}

/// Opt-in and opt-out per channel. Regulators require that an opt-out is never lost or reordered.
public sealed class SubscriberPreferencesService(IDocumentStore store)
{
    public async Task ChangeChannelAsync(Guid subscriberId, string channel, bool enabled, CancellationToken ct)
    {
        await using var session = store.LightweightSession();
        var prefs = await session.Events.AggregateStreamAsync<SubscriberPreferences>(subscriberId, token: ct);
        if (prefs is not null && prefs.IsOptedOut(channel) == !enabled) return;
        session.Events.Append(subscriberId, new PreferenceChanged(subscriberId, channel, enabled));
        await session.SaveChangesAsync(ct);
    }
}
