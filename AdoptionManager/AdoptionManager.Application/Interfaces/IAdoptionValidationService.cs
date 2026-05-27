using AdoptionManager.Application.DTOs;

namespace AdoptionManager.Application.Interfaces;

public interface IAdoptionValidationService
{
    AdoptionVerificationResult Validate(AdoptionVerificationRequest request);
}