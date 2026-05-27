using AdoptionManager.Application.DTOs;
using AdoptionManager.Application.Interfaces;

namespace AdoptionManager.Application.Services;

public class AdoptionValidationService : IAdoptionValidationService
{
    private const int MaxDocumentSizeBytes = 10 * 1024 * 1024;

    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "application/pdf",
        "image/jpeg",
        "image/png"
    };

    public AdoptionVerificationResult Validate(AdoptionVerificationRequest request)
    {
        var errors = new List<string>();

        if (request.PetId == Guid.Empty)
        {
            errors.Add("PetId is required.");
        }

        if (request.UserId == Guid.Empty)
        {
            errors.Add("UserId is required.");
        }

        if (string.IsNullOrWhiteSpace(request.ApplicantName))
        {
            errors.Add("ApplicantName is required.");
        }

        if (string.IsNullOrWhiteSpace(request.ApplicantEmail) || !request.ApplicantEmail.Contains('@'))
        {
            errors.Add("ApplicantEmail must be a valid email address.");
        }

        if (string.IsNullOrWhiteSpace(request.Justification))
        {
            errors.Add("Justification is required.");
        }

        if (request.Documents.Count == 0)
        {
            errors.Add("At least one identity or supporting document is required.");
        }

        var requiredDocumentTypes = GetRequiredDocumentTypes(request);
        var providedDocumentTypes = request.Documents.Select(document => document.DocumentType).Distinct().ToArray();

        foreach (var requiredDocumentType in requiredDocumentTypes)
        {
            if (!providedDocumentTypes.Contains(requiredDocumentType))
            {
                errors.Add($"Missing required document: {requiredDocumentType}.");
            }
        }

        foreach (var document in request.Documents)
        {
            if (string.IsNullOrWhiteSpace(document.FileName))
            {
                errors.Add($"Document '{document.DocumentType}' must have a file name.");
            }

            if (!AllowedContentTypes.Contains(document.ContentType))
            {
                errors.Add($"Document '{document.DocumentType}' must be a PDF, PNG, or JPEG file.");
            }

            if (document.SizeBytes <= 0 || document.SizeBytes > MaxDocumentSizeBytes)
            {
                errors.Add($"Document '{document.DocumentType}' must be between 1 byte and {MaxDocumentSizeBytes} bytes.");
            }
        }

        var missingDocumentTypes = requiredDocumentTypes.Where(requiredDocumentType => !providedDocumentTypes.Contains(requiredDocumentType)).ToArray();

        return new AdoptionVerificationResult
        {
            IsValid = errors.Count == 0,
            Errors = errors,
            RequiredDocumentTypes = requiredDocumentTypes,
            ProvidedDocumentTypes = providedDocumentTypes,
            MissingDocumentTypes = missingDocumentTypes,
            ValidatedAt = DateTimeOffset.UtcNow
        };
    }

    private static AdoptionDocumentType[] GetRequiredDocumentTypes(AdoptionVerificationRequest request)
    {
        var requiredDocumentTypes = new List<AdoptionDocumentType>
        {
            AdoptionDocumentType.GovernmentId,
            AdoptionDocumentType.ProofOfResidence
        };

        if (request.RequiresLandlordConsent)
        {
            requiredDocumentTypes.Add(AdoptionDocumentType.LandlordConsent);
        }

        return requiredDocumentTypes.Distinct().ToArray();
    }
}