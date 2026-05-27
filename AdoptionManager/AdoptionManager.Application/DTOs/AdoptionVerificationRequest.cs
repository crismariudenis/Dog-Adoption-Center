using System.Collections.Generic;

namespace AdoptionManager.Application.DTOs;

public record AdoptionVerificationRequest(
    Guid PetId,
    Guid UserId,
    string ApplicantName,
    string ApplicantEmail,
    string Justification,
    bool RequiresLandlordConsent,
    IReadOnlyCollection<AdoptionDocumentRequest> Documents);