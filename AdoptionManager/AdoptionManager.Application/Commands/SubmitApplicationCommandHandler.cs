using System;
using System.Threading;
using System.Threading.Tasks;
using AdoptionManager.Application.DTOs;
using AdoptionManager.Application.Interfaces;
using AdoptionManager.Application.Services;
using AdoptionManager.Domain.Entities;
using AdoptionManager.Domain.Enums;
using AdoptionManager.Domain.Interfaces;
using MediatR;

namespace AdoptionManager.Application.Commands;

public class SubmitApplicationCommandHandler : IRequestHandler<SubmitApplicationCommand, ApplicationDto>
{
    private readonly IAdoptionRepository _repository;
    private readonly IEventPublisher _events;
    private readonly IAdoptionValidationService _validationService;

    public SubmitApplicationCommandHandler(
        IAdoptionRepository repository,
        IEventPublisher events,
        IAdoptionValidationService validationService)
    {
        _repository = repository;
        _events = events;
        _validationService = validationService;
    }

    public async Task<ApplicationDto> Handle(SubmitApplicationCommand request, CancellationToken cancellationToken)
    {
        var validation = _validationService.Validate(request.ToVerificationRequest());
        if (!validation.IsValid)
        {
            throw new ArgumentException(string.Join(" ", validation.Errors));
        }

        var application = new AdoptionApplication
        {
            Id = Guid.NewGuid(),
            PetId = request.PetId,
            UserId = request.UserId,
            ApplicantName = request.ApplicantName,
            ApplicantEmail = request.ApplicantEmail,
            Justification = request.Justification,
            Status = ApplicationStatus.Submitted,
            SubmittedAt = DateTime.UtcNow
        };

        await _repository.AddAsync(application);

        await _events.PublishApplicationStatusChangedAsync(
            applicationId: application.Id,
            userId: application.UserId,
            userEmail: application.ApplicantEmail,
            userName: application.ApplicantName,
            petName: application.PetId.ToString(),
            oldStatus: string.Empty,
            newStatus: application.Status.ToString(),
            cancellationToken: cancellationToken);

        return new ApplicationDto
        {
            Id = application.Id,
            PetId = application.PetId,
            UserId = application.UserId,
            ApplicantName = application.ApplicantName,
            ApplicantEmail = application.ApplicantEmail,
            Justification = application.Justification,
            Status = application.Status.ToString(),
            SubmittedAt = application.SubmittedAt
        };
    }
}