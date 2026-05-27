using AdoptionManager.Api.Contracts;
using Microsoft.AspNetCore.Http;

namespace AdoptionManager.Api.Services;

public interface ISimpleDocumentAnalysisService
{
    Task<DocumentAnalysisResponse> AnalyzeIdAsync(IFormFile idDocument, string? expectedFullName, CancellationToken cancellationToken);

    Task<DocumentExtractionResponse> AnalyzeDocumentsAsync(
        IFormFile idDocument,
        IFormFile bankStatementDocument,
        string? expectedFullName,
        CancellationToken cancellationToken);
}