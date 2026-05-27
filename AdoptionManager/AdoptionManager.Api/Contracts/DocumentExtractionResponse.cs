namespace AdoptionManager.Api.Contracts;

public class DocumentExtractionResponse
{
    public string? ExtractedIdName { get; set; }

    public string? IdImagePreviewBase64 { get; set; }

    public bool IdNameMatchesExpected { get; set; }

    public bool IdLooksLikeIdentityDocument { get; set; }

    public bool HasFaceLikeRegion { get; set; }

    public IReadOnlyCollection<string> MatchedIdKeywords { get; set; } = Array.Empty<string>();

    public string IdTextPreview { get; set; } = string.Empty;

    public decimal? ExtractedBankBalance { get; set; }

    public string? ExtractedBankCurrency { get; set; }

    public string? ExtractedBankCountry { get; set; }

    public string BankTextPreview { get; set; } = string.Empty;

    public IReadOnlyCollection<string> Warnings { get; set; } = Array.Empty<string>();
}