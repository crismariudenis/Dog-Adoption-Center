namespace AdoptionManager.Api.Contracts;

public class DocumentAnalysisResponse
{
    public bool IsImageDocument { get; set; }

    public bool HasImageData { get; set; }

    public string? ExtractedName { get; set; }

    public bool NameMatchesExpected { get; set; }

    public bool HasFaceLikeRegion { get; set; }

    public string ExtractedTextPreview { get; set; } = string.Empty;

    public IReadOnlyCollection<string> Warnings { get; set; } = Array.Empty<string>();
}