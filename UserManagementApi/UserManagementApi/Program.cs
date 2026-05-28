using FluentValidation;
using Microsoft.EntityFrameworkCore;
using UserManagementApi.Application.DTOs;
using UserManagementApi.Application.Services;
using UserManagementApi.Application.Validators;
using UserManagementApi.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddDbContext<ApplicationContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IValidator<CreateUserRequest>, CreateUserRequestValidator>();
builder.Services.AddScoped<IValidator<UpdateUserRequest>, UpdateUserRequestValidator>();

builder.Services.AddEndpointsApiExplorer();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
}

app.UseHttpsRedirection();

// Create the database if it doesn't exist
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var context = services.GetRequiredService<ApplicationContext>();
    context.Database.EnsureCreated();
}

// Add endpoints
app.MapPost("/users", async (IUserService userService, IValidator<CreateUserRequest> validator, CreateUserRequest request) =>
{
    var validationResult = await validator.ValidateAsync(request);
    if (!validationResult.IsValid)
    {
        return Results.ValidationProblem(validationResult.ToDictionary());
    }

    var newUser = await userService.AddUserAsync(request.Username, request.Email, request.Password);
    return Results.Ok(newUser);
});

app.MapPost("/login", async (IUserService userService, LoginRequest request) =>
{
    var token = await userService.LoginAsync(request.Email, request.Password);
    if (token == null)
    {
        return Results.Unauthorized();
    }
    return Results.Ok(new { Token = token });
});

app.MapGet("/users", async (IUserService userService) =>
{
    var users = await userService.GetAllUsersAsync();
    return Results.Ok(users);
});

app.MapGet("/users/{id}", async (IUserService userService, Guid id) =>
{
    var user = await userService.GetUserByIdAsync(id);
    if (user == null)
    {
        return Results.NotFound();
    }
    return Results.Ok(user);
});

app.MapPut("/users/{id}", async (IUserService userService, IValidator<UpdateUserRequest> validator, Guid id, UpdateUserRequest request) =>
{
    var validationResult = await validator.ValidateAsync(request);
    if (!validationResult.IsValid)
    {
        return Results.ValidationProblem(validationResult.ToDictionary());
    }

    var updatedUser = await userService.UpdateUserAsync(id, request.Username, request.Email);
    if (updatedUser == null)
    {
        return Results.NotFound();
    }
    return Results.Ok(updatedUser);
});

app.MapDelete("/users/{id}", async (IUserService userService, Guid id) =>
{
    var result = await userService.DeleteUserAsync(id);
    if (!result)
    {
        return Results.NotFound();
    }
    return Results.Ok();
});

app.Run();
