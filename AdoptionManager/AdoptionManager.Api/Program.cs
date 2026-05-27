using AdoptionManager.Application.Commands;
using AdoptionManager.Application.Interfaces;
using AdoptionManager.Application.Services;
using AdoptionManager.Domain.Interfaces;
using AdoptionManager.Infrastructure.Messaging;
using AdoptionManager.Infrastructure.Persistence;
using AdoptionManager.Api.Services;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure MediatR
builder.Services.AddMediatR(cfg => {
    cfg.RegisterServicesFromAssembly(typeof(SubmitApplicationCommand).Assembly);
});

builder.Services.AddSingleton<IAdoptionValidationService, AdoptionValidationService>();
builder.Services.AddSingleton<ISimpleDocumentAnalysisService, SimpleDocumentAnalysisService>();

// Configure CosmosDB
var useLocalMode = string.Equals(
    Environment.GetEnvironmentVariable("ADOPTION_MANAGER_LOCAL"),
    "true",
    StringComparison.OrdinalIgnoreCase);
var cosmosUri = Environment.GetEnvironmentVariable("COSMOS_URI") ?? builder.Configuration["CosmosDb:Uri"];
var cosmosKey = Environment.GetEnvironmentVariable("COSMOS_KEY");
var useLocalStorage = useLocalMode || string.IsNullOrWhiteSpace(cosmosUri);

if (useLocalStorage)
{
    builder.Services.AddSingleton<IAdoptionRepository, InMemoryAdoptionRepository>();
}
else
{
    builder.Services.AddSingleton<CosmosClient>(sp =>
    {
        if (!string.IsNullOrEmpty(cosmosKey))
        {
            return new CosmosClient(cosmosUri, cosmosKey);
        }

        throw new InvalidOperationException("COSMOS_KEY is required when COSMOS_URI is set for the cloud deployment path.");
    });

    builder.Services.AddScoped<IAdoptionRepository>(sp =>
    {
        var client = sp.GetRequiredService<CosmosClient>();
        return new CosmosAdoptionRepository(client, "AdoptionDb", "Applications");
    });
}

var serviceBusConnection = Environment.GetEnvironmentVariable("SERVICE_BUS_CONNECTION_STRING")
    ?? builder.Configuration["ServiceBus:ConnectionString"];
var serviceBusQueue = Environment.GetEnvironmentVariable("SERVICE_BUS_QUEUE_NAME")
    ?? builder.Configuration["ServiceBus:QueueName"]
    ?? "application-status-changed";

if (useLocalMode || string.IsNullOrWhiteSpace(serviceBusConnection))
{
    builder.Services.AddSingleton<IEventPublisher, NoopEventPublisher>();
}
else
{
    builder.Services.AddSingleton(new ServiceBusClient(serviceBusConnection));
    builder.Services.AddSingleton<IEventPublisher>(sp =>
        new ServiceBusEventPublisher(
            sp.GetRequiredService<ServiceBusClient>(),
            serviceBusQueue,
            sp.GetRequiredService<ILogger<ServiceBusEventPublisher>>()));
}

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Ensure Database and Container are created only for the cloud-backed path
if (!useLocalStorage)
{
    using var scope = app.Services.CreateScope();
    var client = scope.ServiceProvider.GetRequiredService<CosmosClient>();
    var database = await client.CreateDatabaseIfNotExistsAsync("AdoptionDb");
    await database.Database.CreateContainerIfNotExistsAsync("Applications", "/id");
}

app.Run();
