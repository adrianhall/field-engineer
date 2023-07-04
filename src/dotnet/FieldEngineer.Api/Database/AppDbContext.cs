using FieldEngineer.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FieldEngineer.Api.Database
{
    public class AppDbContext : DbContext, IDatabaseInitializer
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        /*
         * Database entities definition.
         */
        public DbSet<Customer> Customers => Set<Customer>();
        public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();

        /*
         * Database initializer.
         */
        public async Task InitializeDatabaseAsync(CancellationToken cancellationToken = default)
        {
            // Ensure the database exists and is up to date.
            await Database.EnsureCreatedAsync(cancellationToken).ConfigureAwait(false);
        }
    }
}
