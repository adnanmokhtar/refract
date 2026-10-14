using MassTransit;
using Microsoft.AspNetCore.Mvc;
using Notify.Api.Data;

namespace Notify.Api.Controllers;

public record CustomerProfileChanged(string CustomerId, string Email, string Phone, DateTimeOffset UpdatedAt, string Source);

/// The preference centre. apps/worker's customer-profile consumer mirrors every change it publishes.
[ApiController]
[Route("preferences")]
public sealed class PreferencesController(NotifyDbContext db, IPublishEndpoint publishEndpoint) : ControllerBase
{
    [HttpPut("{customerId}")]
    public async Task<IActionResult> Update(string customerId, [FromBody] ContactPreference body, CancellationToken ct)
    {
        body.CustomerId = customerId;
        body.UpdatedAt = DateTimeOffset.UtcNow;
        db.Preferences.Update(body);
        await db.SaveChangesAsync(ct);
        await publishEndpoint.Publish(new CustomerProfileChanged(customerId, body.Email, body.Phone, body.UpdatedAt, "notify-preferences"), ct);
        return NoContent();
    }
}
