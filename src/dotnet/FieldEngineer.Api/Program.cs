using Azure.Identity;
using FieldEngineer.Api.Database;
using Microsoft.AspNetCore.Datasync;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

/*****************************************************************************************
 *
 * SET UP CONFIGURATION
 */
var keyVaultUri = builder.Configuration["FieldEngineer:KeyVault:Uri"];
if (!string.IsNullOrEmpty(keyVaultUri))
{
    builder.Configuration.AddAzureKeyVault(new Uri(keyVaultUri), new DefaultAzureCredential());
}

/*
 * Allow developers to override the configuration with user secrets.
 */
if (builder.Environment.IsDevelopment())
{
    builder.Configuration.AddUserSecrets<Program>(optional: true);
}

/*****************************************************************************************
 *
 * BUILD THE SERVICES COLLECTION
 */

/*
 * Enable logging
 */
builder.Services.AddApplicationInsightsTelemetry();
if (builder.Environment.IsDevelopment())
{
    builder.Logging.AddConsole();
}

/*
 * Add a database context, with either the connection string or managed identity.
 */
var connectionString = builder.Configuration["FieldEngineer:Sql:ConnectionString"];
if (!string.IsNullOrEmpty(connectionString))
{
    builder.Services.AddDbContext<AppDbContext>(options =>
        options.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure())
    );
}

/*
 * Response compression.
 */
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddResponseCompression(options => options.EnableForHttps = true);
}

/*
 * Enable Datasync-capable controllers.
 */
builder.Services.AddDatasyncControllers();

/*****************************************************************************************
 *
 * BUILD THE HTTP PIPELINE
 */
var app = builder.Build();

/*
 * Initialize the database - only if using development.
 */
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetService<AppDbContext>();
    if (dbContext is IDatabaseInitializer dbInitializer)
    {
        await dbInitializer.InitializeDatabaseAsync();
    }
}

/*
 * Set up basic HTTPS middleware.
 */
app.UseHttpsRedirection();
if (!app.Environment.IsDevelopment())
{
    app.UseResponseCompression();
}

/*
 * Authentication and Authorization.
 */
app.UseAuthorization();

/*
 * Map controller paths, per normal ASP.NET Core standards.
 */
app.MapControllers();

/*
 * Run the application!
 */
app.Run();
