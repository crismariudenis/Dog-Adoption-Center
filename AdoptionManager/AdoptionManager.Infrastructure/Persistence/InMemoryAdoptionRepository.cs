using System.Collections.Concurrent;
using AdoptionManager.Domain.Entities;
using AdoptionManager.Domain.Interfaces;

namespace AdoptionManager.Infrastructure.Persistence;

public class InMemoryAdoptionRepository : IAdoptionRepository
{
    private static readonly ConcurrentDictionary<Guid, AdoptionApplication> Applications = new();

    public Task<AdoptionApplication?> GetByIdAsync(Guid id)
    {
        Applications.TryGetValue(id, out var application);
        return Task.FromResult(application);
    }

    public Task<IEnumerable<AdoptionApplication>> GetByUserIdAsync(Guid userId)
    {
        var results = Applications.Values.Where(application => application.UserId == userId);
        return Task.FromResult<IEnumerable<AdoptionApplication>>(results);
    }

    public Task<IEnumerable<AdoptionApplication>> GetByPetIdAsync(Guid petId)
    {
        var results = Applications.Values.Where(application => application.PetId == petId);
        return Task.FromResult<IEnumerable<AdoptionApplication>>(results);
    }

    public Task AddAsync(AdoptionApplication application)
    {
        Applications[application.Id] = application;
        return Task.CompletedTask;
    }

    public Task UpdateAsync(AdoptionApplication application)
    {
        Applications[application.Id] = application;
        return Task.CompletedTask;
    }
}