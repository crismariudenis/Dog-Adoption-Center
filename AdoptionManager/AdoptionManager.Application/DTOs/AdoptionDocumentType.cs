using System.Text.Json.Serialization;

namespace AdoptionManager.Application.DTOs;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum AdoptionDocumentType
{
    GovernmentId,
    ProofOfResidence,
    LandlordConsent,
    VeterinaryReference,
    PetOwnershipAgreement
}