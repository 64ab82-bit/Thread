using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Server.Models
{
    [Table("Reactions")]
    public class Reaction
    {
        [Key]
        public int Id { get; set; }
        public int CommentId { get; set; }
        public int UserId { get; set; }
        public string ReactionType { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
