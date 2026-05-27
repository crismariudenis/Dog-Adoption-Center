namespace AdoptionManager.Application.DTOs;

public record AdoptionDocumentRequest(
    AdoptionDocumentType DocumentType,
    string FileName,
    string ContentType,
    long SizeBytes);