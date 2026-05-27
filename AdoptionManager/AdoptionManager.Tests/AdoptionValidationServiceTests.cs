using AdoptionManager.Application.DTOs;
using AdoptionManager.Application.Services;
using Xunit;

namespace AdoptionManager.Tests;

public class AdoptionValidationServiceTests
{
    private readonly AdoptionValidationService _service = new();

    [Fact]
    public void Validate_ReturnsValidResult_WhenRequiredDocumentsArePresent()
    {
        var request = new AdoptionVerificationRequest(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "Ada Lovelace",
            "ada@example.com",
            "I have a stable home and experience with dogs.",
            true,
            new[]
            {
                new AdoptionDocumentRequest(AdoptionDocumentType.GovernmentId, "id.pdf", "application/pdf", 1024),
                new AdoptionDocumentRequest(AdoptionDocumentType.ProofOfResidence, "proof-of-address.png", "image/png", 2048),
                new AdoptionDocumentRequest(AdoptionDocumentType.LandlordConsent, "consent.jpeg", "image/jpeg", 2048)
            });

        var result = _service.Validate(request);

        Assert.True(result.IsValid);
        Assert.Empty(result.Errors);
        Assert.Contains(AdoptionDocumentType.GovernmentId, result.RequiredDocumentTypes);
        Assert.Contains(AdoptionDocumentType.ProofOfResidence, result.RequiredDocumentTypes);
        Assert.Contains(AdoptionDocumentType.LandlordConsent, result.RequiredDocumentTypes);
    }

    [Fact]
    public void Validate_ReturnsMissingDocumentErrors_WhenIdOrAddressProofIsAbsent()
    {
        var request = new AdoptionVerificationRequest(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "Ada Lovelace",
            "ada@example.com",
            "I have a stable home and experience with dogs.",
            false,
            new[]
            {
                new AdoptionDocumentRequest(AdoptionDocumentType.GovernmentId, "id.pdf", "application/pdf", 1024)
            });

        var result = _service.Validate(request);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.Contains("ProofOfResidence", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(AdoptionDocumentType.ProofOfResidence, result.MissingDocumentTypes);
    }
}