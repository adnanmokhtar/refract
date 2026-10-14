namespace Notify.Api.Sms;

public sealed class SmsProviderClient(HttpClient http)
{
    public async Task SendAsync(string to, string text, CancellationToken ct)
    {
        using var res = await http.PostAsJsonAsync("/v1/messages", new { to, text }, ct);
        res.EnsureSuccessStatusCode();
    }
}
