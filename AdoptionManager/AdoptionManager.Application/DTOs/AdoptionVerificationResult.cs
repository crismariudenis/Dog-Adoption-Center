namespace AdoptionManager.Application.DTOs;

public class AdoptionVerificationResult
{
    public bool IsValid { get; set; }

    public IReadOnlyCollection<string> Errors { get; set; } = Array.Empty<string>();

    public IReadOnlyCollection<AdoptionDocumentType> RequiredDocumentTypes { get; set; } = Array.Empty<AdoptionDocumentType>();

    public IReadOnlyCollection<AdoptionDocumentType> ProvidedDocumentTypes { get; set; } = Array.Empty<AdoptionDocumentType>();

    public IReadOnlyCollection<AdoptionDocumentType> MissingDocumentTypes { get; set; } = Array.Empty<AdoptionDocumentType>();

    public DateTimeOffset ValidatedAt { get; set; }
}