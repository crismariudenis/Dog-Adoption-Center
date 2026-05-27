using System;
using System.Threading.Tasks;
using AdoptionManager.Api.Contracts;
using AdoptionManager.Api.Services;
using AdoptionManager.Application.Commands;
using AdoptionManager.Application.DTOs;
using AdoptionManager.Application.Interfaces;
using AdoptionManager.Application.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace AdoptionManager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdoptionController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IAdoptionValidationService _validationService;
    private readonly ISimpleDocumentAnalysisService _documentAnalysisService;

    public AdoptionController(
        IMediator mediator,
        IAdoptionValidationService validationService,
        ISimpleDocumentAnalysisService documentAnalysisService)
    {
        _mediator = mediator;
        _validationService = validationService;
        _documentAnalysisService = documentAnalysisService;
    }

    [HttpPost]
    public async Task<ActionResult<ApplicationDto>> SubmitApplication([FromBody] SubmitApplicationCommand command)
    {
        try
        {
            var result = await _mediator.Send(command);
            return CreatedAtAction(nameof(GetApplication), new { id = result.Id }, result);
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new { errors = exception.Message });
        }
    }

    [HttpPost("validate")]
    public ActionResult<AdoptionVerificationResult> ValidateApplication([FromBody] SubmitApplicationCommand command)
    {
        var result = _validationService.Validate(command.ToVerificationRequest());
        return Ok(result);
    }

    [HttpPost("scan-id")]
    [RequestSizeLimit(10_000_000)]
    public async Task<ActionResult<DocumentAnalysisResponse>> ScanIdDocument(
        [FromForm] IFormFile idDocument,
        [FromForm] string? expectedFullName,
        CancellationToken cancellationToken)
    {
        if (idDocument == null || idDocument.Length == 0)
        {
            return BadRequest(new { errors = "idDocument is required." });
        }

        var analysis = await _documentAnalysisService.AnalyzeIdAsync(idDocument, expectedFullName, cancellationToken);
        if (!analysis.HasFaceLikeRegion)
        {
            return BadRequest(new { errors = "Could not detect a face-like photo region in the ID document." });
        }

        return Ok(analysis);
    }

    [HttpPost("scan-documents")]
    [RequestSizeLimit(20_000_000)]
    public async Task<ActionResult<DocumentExtractionResponse>> ScanDocuments(
        [FromForm] IFormFile idDocument,
        [FromForm] IFormFile bankStatementDocument,
        [FromForm] string? expectedFullName,
        CancellationToken cancellationToken)
    {
        if (idDocument == null || idDocument.Length == 0)
        {
            return BadRequest(new { errors = "idDocument is required." });
        }

        if (bankStatementDocument == null || bankStatementDocument.Length == 0)
        {
            return BadRequest(new { errors = "bankStatementDocument is required." });
        }

        var extraction = await _documentAnalysisService.AnalyzeDocumentsAsync(
            idDocument,
            bankStatementDocument,
            expectedFullName,
            cancellationToken);

        if (!extraction.HasFaceLikeRegion)
        {
            return BadRequest(new { errors = "Could not detect a face-like photo region in the ID document." });
        }

        return Ok(extraction);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApplicationDto>> GetApplication(Guid id)
    {
        var result = await _mediator.Send(new GetApplicationQuery(id));
        if (result == null)
            return NotFound();

        return Ok(result);
    }
}