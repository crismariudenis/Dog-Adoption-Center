using AdoptionManager.Application.Interfaces;

namespace AdoptionManager.Infrastructure.Messaging;

public class NoopEventPublisher : IEventPublisher
{
    public Task PublishApplicationStatusChangedAsync(
        Guid applicationId,
        Guid userId,
        string userEmail,
        string userName,
        string petName,
        string oldStatus,
        string newStatus,
        CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }
}