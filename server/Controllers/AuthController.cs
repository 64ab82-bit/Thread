using Microsoft.AspNetCore.Mvc;
using Server.Models;
using System.Security.Cryptography;
using System.Text;

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

        [HttpPost("register")]

        public IActionResult Register([FromBody] RegisterRequest req)
        {
            if (_db.Users.Any(u => u.Username == req.Username))
                return BadRequest("ユーザー名は既に存在します");

            var hash = HashPassword(req.Password);
            var user = new User
            {
                Username = req.Username,
                PasswordHash = hash,
                DisplayName = req.DisplayName,
                AvatarUrl = req.AvatarUrl,
                CreatedAt = DateTime.Now
            };
            _db.Users.Add(user);
            _db.SaveChanges();
            return Ok(new { user.Id, user.Username });
        }

        [HttpPost("login")]

        public IActionResult Login([FromBody] LoginRequest req)
        {
            var user = _db.Users.FirstOrDefault(u => u.Username == req.Username);
            if (user == null || user.PasswordHash != HashPassword(req.Password))
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

        private static string HashPassword(string password)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
            return BitConverter.ToString(bytes).Replace("-", "").ToLower();
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
}
