using UserManagementApi.Domain.Entities;

namespace UserManagementApi.Application.Services;

public interface IUserService
{
    Task<User> AddUserAsync(string username, string email, string password);
    Task<string?> LoginAsync(string email, string password);
    Task<IEnumerable<User>> GetAllUsersAsync();
    Task<User?> GetUserByIdAsync(Guid id);
    Task<User?> UpdateUserAsync(Guid id, string username, string email);
    Task<bool> DeleteUserAsync(Guid id);
}
