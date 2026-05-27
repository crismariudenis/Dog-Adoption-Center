using System;
using System.Collections.Generic;
using AdoptionManager.Application.DTOs;
using MediatR;

namespace AdoptionManager.Application.Commands;

public record SubmitApplicationCommand(
    Guid PetId,
    Guid UserId,
    string ApplicantName,
    string ApplicantEmail,
    string Justification) : IRequest<ApplicationDto>
{
    public bool RequiresLandlordConsent { get; init; }

    public IReadOnlyCollection<AdoptionDocumentRequest> Documents { get; init; } = Array.Empty<AdoptionDocumentRequest>();

    public AdoptionVerificationRequest ToVerificationRequest()
    {
        return new AdoptionVerificationRequest(
            PetId,
            UserId,
            ApplicantName,
            ApplicantEmail,
            Justification,
            RequiresLandlordConsent,
            Documents);
    }
}