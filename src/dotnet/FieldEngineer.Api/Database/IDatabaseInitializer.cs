namespace FieldEngineer.Api.Database
{
    public interface IDatabaseInitializer
    {
        Task InitializeDatabaseAsync(CancellationToken cancellationToken = default);
    }
}
