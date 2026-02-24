using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Data;
using Server.Models;
using System.Text;
using System.Text.Json;

namespace Server.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ThreadsController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;

        public ThreadsController(AppDbContext db, IHttpClientFactory httpClientFactory, IConfiguration configuration)
        {
            _db = db;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
        }

        [HttpGet]
        public async Task<IActionResult> GetThreads([FromQuery] string? title, [FromQuery] DateTime? date)
        {
            var query = _db.Threads
                .Include(t => t.Comments)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(title))
            {
                var q = title.Trim();
                query = query.Where(t => t.Title.Contains(q));
            }

            if (date.HasValue)
            {
                var day = date.Value.Date;
                query = query.Where(t => t.CreatedAt >= day && t.CreatedAt < day.AddDays(1));
            }

            var threads = await query
                .OrderByDescending(t => t.CreatedAt)
                .ToListAsync();

            var userIds = threads.Select(t => t.CreatedBy)
                .Concat(threads.SelectMany(t => (t.Comments ?? []).Select(c => c.UserId)))
                .Distinct()
                .ToList();

            var users = await _db.Users
                .Where(u => userIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id);

            var commentIds = threads
                .SelectMany(t => t.Comments ?? [])
                .Select(c => c.Id)
                .ToList();

            var reactions = await _db.Reactions
                .Where(r => commentIds.Contains(r.CommentId))
                .ToListAsync();

            var reactionsByComment = reactions
                .GroupBy(r => r.CommentId)
                .ToDictionary(
                    g => g.Key,
                    g => g.GroupBy(x => x.ReactionType)
                        .ToDictionary(x => x.Key, x => x.Count())
                );

            var result = threads.Select(t => new {
                id = t.Id,
                title = t.Title,
                category = t.Category,
                createdBy = t.CreatedBy,
                createdByName = users.TryGetValue(t.CreatedBy, out var threadUser)
                    ? threadUser.DisplayName ?? threadUser.Username
                    : "不明ユーザー",
                createdAt = t.CreatedAt,
                comments = t.Comments?.OrderBy(c => c.CreatedAt).Select(c => new {
                    id = c.Id,
                    threadId = c.ThreadId,
                    userId = c.UserId,
                    userName = users.TryGetValue(c.UserId, out var user)
                        ? user.DisplayName ?? user.Username
                        : "不明ユーザー",
                    avatarUrl = users.TryGetValue(c.UserId, out var avatarUser)
                        ? avatarUser.AvatarUrl
                        : null,
                    content = c.Content,
                    parentCommentId = c.ParentCommentId,
                    createdAt = c.CreatedAt,
                    reactions = reactionsByComment.TryGetValue(c.Id, out var grouped) ? grouped : new Dictionary<string, int>()
                })
            });
            return Ok(result);
        }

        [HttpGet("category-suggestions")]
        public async Task<IActionResult> GetCategorySuggestions([FromQuery] string query)
        {
            var prompt = query.Trim();
            if (string.IsNullOrWhiteSpace(prompt))
            {
                return Ok(Array.Empty<string>());
            }

            var openAiApiKey = _configuration["OPENAI_API_KEY"];
            if (!string.IsNullOrWhiteSpace(openAiApiKey))
            {
                try
                {
                    var client = _httpClientFactory.CreateClient();
                    client.DefaultRequestHeaders.Authorization =
                        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", openAiApiKey);

                    var payload = new
                    {
                        model = "gpt-4o-mini",
                        messages = new object[]
                        {
                            new { role = "system", content = "あなたは掲示板カテゴリ提案アシスタントです。3件だけ短いカテゴリ名を提案してください。JSON配列のみ返してください。" },
                            new { role = "user", content = $"入力語: {prompt}" }
                        },
                        temperature = 0.4
                    };

                    var response = await client.PostAsync(
                        "https://api.openai.com/v1/chat/completions",
                        new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"));

                    if (response.IsSuccessStatusCode)
                    {
                        using var stream = await response.Content.ReadAsStreamAsync();
                        using var doc = await JsonDocument.ParseAsync(stream);
                        var content = doc.RootElement
                            .GetProperty("choices")[0]
                            .GetProperty("message")
                            .GetProperty("content")
                            .GetString();

                        if (!string.IsNullOrWhiteSpace(content))
                        {
                            var cleaned = content.Trim().Trim('`');
                            if (cleaned.StartsWith("json", StringComparison.OrdinalIgnoreCase))
                            {
                                cleaned = cleaned.Substring(4).Trim();
                            }

                            try
                            {
                                var list = JsonSerializer.Deserialize<List<string>>(cleaned);
                                if (list is { Count: > 0 })
                                {
                                    return Ok(list.Where(s => !string.IsNullOrWhiteSpace(s)).Select(s => s.Trim()).Distinct().Take(5));
                                }
                            }
                            catch
                            {
                                // fallback to local suggestions
                            }
                        }
                    }
                }
                catch
                {
                    // fallback to local suggestions
                }
            }

            var fallback = BuildFallbackSuggestions(prompt);
            return Ok(fallback);
        }

        [HttpPost]
        public async Task<IActionResult> CreateThread([FromBody] CreateThreadRequest req)
        {
            var thread = new DiscussionThread {
                Title = req.Title,
                Category = req.Category.Trim(),
                CreatedBy = req.CreatedBy,
                CreatedAt = DateTime.Now
            };
            _db.Threads.Add(thread);
            await _db.SaveChangesAsync();
            return Ok(new { thread.Id, thread.Title, thread.Category });
        }

        [HttpPost("comment")]
        public async Task<IActionResult> PostComment([FromBody] PostCommentRequest req)
        {
            var comment = new Comment {
                ThreadId = req.ThreadId,
                UserId = req.UserId,
                Content = req.Content,
                ParentCommentId = req.ParentCommentId,
                CreatedAt = DateTime.Now
            };
            _db.Comments.Add(comment);
            await _db.SaveChangesAsync();
            return Ok(new { comment.Id, comment.ThreadId, comment.UserId, comment.Content, comment.ParentCommentId, comment.CreatedAt });
        }

        [HttpPost("reaction")]
        public async Task<IActionResult> PostReaction([FromBody] PostReactionRequest req)
        {
            var existing = await _db.Reactions.FirstOrDefaultAsync(r =>
                r.CommentId == req.CommentId &&
                r.UserId == req.UserId &&
                r.ReactionType == req.ReactionType);

            if (existing != null)
            {
                _db.Reactions.Remove(existing);
            }
            else
            {
                var reaction = new Reaction {
                    CommentId = req.CommentId,
                    UserId = req.UserId,
                    ReactionType = req.ReactionType,
                    CreatedAt = DateTime.Now
                };
                _db.Reactions.Add(reaction);
            }

            await _db.SaveChangesAsync();

            var grouped = await _db.Reactions
                .Where(r => r.CommentId == req.CommentId)
                .GroupBy(r => r.ReactionType)
                .Select(g => new { reactionType = g.Key, count = g.Count() })
                .ToListAsync();

            return Ok(grouped);
        }

        private static IEnumerable<string> BuildFallbackSuggestions(string input)
        {
            var lower = input.ToLowerInvariant();
            var pool = new List<string>();

            if (lower.Contains("flutter") || lower.Contains("dart") || lower.Contains("開発"))
            {
                pool.AddRange(new[] { "技術", "モバイル開発", "プログラミング" });
            }
            if (lower.Contains("ai") || lower.Contains("chatgpt") || lower.Contains("llm"))
            {
                pool.AddRange(new[] { "AI", "生成AI", "機械学習" });
            }
            if (lower.Contains("仕事") || lower.Contains("業務") || lower.Contains("運用"))
            {
                pool.AddRange(new[] { "業務", "ナレッジ共有", "改善" });
            }

            if (pool.Count == 0)
            {
                pool.AddRange(new[] { "雑談", "お知らせ", "質問" });
            }

            return pool.Distinct().Take(5);
        }
    }

    public class CreateThreadRequest { public string Title { get; set; } = string.Empty; public string Category { get; set; } = string.Empty; public int CreatedBy { get; set; } }
    public class PostCommentRequest { public int ThreadId { get; set; } public int UserId { get; set; } public string Content { get; set; } = string.Empty; public int? ParentCommentId { get; set; } }
    public class PostReactionRequest { public int CommentId { get; set; } public int UserId { get; set; } public string ReactionType { get; set; } = string.Empty; }
}
