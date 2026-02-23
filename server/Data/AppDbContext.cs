using Microsoft.EntityFrameworkCore;
using Server.Models;

namespace Server.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<User> Users => Set<User>();
        public DbSet<Server.Models.DiscussionThread> Threads => Set<Server.Models.DiscussionThread>();
        public DbSet<Server.Models.Comment> Comments => Set<Server.Models.Comment>();
        public DbSet<Server.Models.Reaction> Reactions => Set<Server.Models.Reaction>();
    }
}