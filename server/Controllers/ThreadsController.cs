using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Data;
using Server.Models;

namespace Server.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ThreadsController : ControllerBase
    {
        private readonly AppDbContext _db;
        public ThreadsController(AppDbContext db) { _db = db; }

        [HttpGet]
        public async Task<IActionResult> GetThreads()
        {
            var threads = await _db.Threads
                .Include(t => t.Comments)
                .OrderByDescending(t => t.CreatedAt)
                .ToListAsync();

            var result = threads.Select(t => new {
                id = t.Id,
                title = t.Title,
                createdBy = t.CreatedBy,
                createdAt = t.CreatedAt,
                comments = t.Comments?.OrderBy(c => c.CreatedAt).Select(c => new {
                    id = c.Id,
                    threadId = c.ThreadId,
                    userId = c.UserId,
                    content = c.Content,
                    parentCommentId = c.ParentCommentId,
                    createdAt = c.CreatedAt
                })
            });
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> CreateThread([FromBody] CreateThreadRequest req)
        {
            var thread = new DiscussionThread { Title = req.Title, CreatedBy = req.CreatedBy, CreatedAt = DateTime.Now };
            _db.Threads.Add(thread);
            await _db.SaveChangesAsync();
            return Ok(new { thread.Id, thread.Title });
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
            // For simplicity, allow multiple same reactions; in production toggle or dedupe
            var reaction = new Reaction {
                CommentId = req.CommentId,
                UserId = req.UserId,
                ReactionType = req.ReactionType,
                CreatedAt = DateTime.Now
            };
            _db.Reactions.Add(reaction);
            await _db.SaveChangesAsync();
            return Ok(new { reaction.Id });
        }
    }

    public class CreateThreadRequest { public string Title { get; set; } = string.Empty; public int CreatedBy { get; set; } }
    public class PostCommentRequest { public int ThreadId { get; set; } public int UserId { get; set; } public string Content { get; set; } = string.Empty; public int? ParentCommentId { get; set; } }
    public class PostReactionRequest { public int CommentId { get; set; } public int UserId { get; set; } public string ReactionType { get; set; } = string.Empty; }
}
