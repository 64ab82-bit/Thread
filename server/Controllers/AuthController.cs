using Microsoft.AspNetCore.Mvc;
using Server.Models;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace Server.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {

        private readonly Server.Data.AppDbContext _db;
        public AuthController(Server.Data.AppDbContext db)
        {
            _db = db;
        }

        [HttpGet("check-username")]
        public async Task<IActionResult> CheckUsername([FromQuery] string username)
        {
            var normalized = username.Trim();
            if (string.IsNullOrWhiteSpace(normalized))
            {
                return BadRequest(new { available = false, message = "ユーザーIDを入力してください" });
            }

            var exists = await _db.Users.AnyAsync(u => u.Username == normalized);
            return Ok(new { available = !exists });
        }

        [HttpPost("register")]

        public async Task<IActionResult> Register([FromBody] RegisterRequest req)
        {
            var username = req.Username.Trim();
            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(req.Password))
            {
                return BadRequest("ユーザーIDとパスワードは必須です");
            }

            if (await _db.Users.AnyAsync(u => u.Username == username))
            {
                return BadRequest("ユーザー名は既に存在します");
            }

            var hash = HashPasswordPbkdf2(req.Password);
            var user = new User
            {
                Username = username,
                PasswordHash = hash,
                DisplayName = req.DisplayName?.Trim(),
                AvatarUrl = req.AvatarUrl?.Trim(),
                CreatedAt = DateTime.Now
            };
            _db.Users.Add(user);
            await _db.SaveChangesAsync();
            return Ok(new { user.Id, user.Username, user.DisplayName, user.AvatarUrl });
        }

        [HttpPost("login")]

        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            var username = req.Username.Trim();
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user == null || !VerifyPassword(req.Password, user.PasswordHash))
                return Unauthorized();
            return Ok(new { user.Id, user.Username, user.DisplayName, user.AvatarUrl });
        }

        [HttpPost("update")]
        public IActionResult UpdateProfile([FromBody] UpdateProfileRequest req)
        {
            var user = _db.Users.Find(req.Id);
            if (user == null) return NotFound();
            user.DisplayName = req.DisplayName;
            user.AvatarUrl = req.AvatarUrl;
            _db.SaveChanges();
            return Ok(new { user.Id, user.DisplayName, user.AvatarUrl });
        }

        [HttpPost("change-password")]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest req)
        {
            var user = await _db.Users.FindAsync(req.Id);
            if (user == null) return NotFound();
            
            if (!VerifyPassword(req.CurrentPassword, user.PasswordHash))
            {
                return BadRequest("現在のパスワードが正しくありません");
            }

            if (string.IsNullOrWhiteSpace(req.NewPassword))
            {
                return BadRequest("新しいパスワードを入力してください");
            }

            user.PasswordHash = HashPasswordPbkdf2(req.NewPassword);
            await _db.SaveChangesAsync();
            return Ok(new { message = "パスワードを変更しました" });
        }

        private static string HashPasswordLegacy(string password)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
            return BitConverter.ToString(bytes).Replace("-", "").ToLower();
        }

        private static string HashPasswordPbkdf2(string password)
        {
            var salt = RandomNumberGenerator.GetBytes(16);
            const int iterations = 100_000;
            var hash = Rfc2898DeriveBytes.Pbkdf2(
                password,
                salt,
                iterations,
                HashAlgorithmName.SHA256,
                32);

            return $"pbkdf2${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
        }

        private static bool VerifyPassword(string inputPassword, string savedHash)
        {
            if (savedHash.StartsWith("pbkdf2$", StringComparison.Ordinal))
            {
                var parts = savedHash.Split('$');
                if (parts.Length != 4)
                {
                    return false;
                }

                if (!int.TryParse(parts[1], out var iterations))
                {
                    return false;
                }

                var salt = Convert.FromBase64String(parts[2]);
                var expectedHash = Convert.FromBase64String(parts[3]);
                var inputHash = Rfc2898DeriveBytes.Pbkdf2(
                    inputPassword,
                    salt,
                    iterations,
                    HashAlgorithmName.SHA256,
                    expectedHash.Length);

                return CryptographicOperations.FixedTimeEquals(inputHash, expectedHash);
            }

            return savedHash == HashPasswordLegacy(inputPassword);
        }
    }

    public class RegisterRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? DisplayName { get; set; }
        public string? AvatarUrl { get; set; }
    }
    public class LoginRequest
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class UpdateProfileRequest
    {
        public int Id { get; set; }
        public string? DisplayName { get; set; }
        public string? AvatarUrl { get; set; }
    }
    public class ChangePasswordRequest
    {
        public int Id { get; set; }
        public string CurrentPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
