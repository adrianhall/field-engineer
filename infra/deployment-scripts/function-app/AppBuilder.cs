using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

using Azure.Data.AppConfiguration;
using Azure.Identity;

using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

using Newtonsoft.Json;


namespace FieldEngineer.Build
{
    public class AppBuilder
    {
        private readonly string appConfigurationService;
        private readonly string sqlConnectionString;

        private AppBuilder()
        {
            appConfigurationService = GetEnvironmentVariable("Azure:AppConfiguration:Endpoint");
            sqlConnectionString = GetEnvironmentVariable("Azure:Sql:ConnectionString");
        }

        private string GetEnvironmentVariable(string name)
        {
            return Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
        }

        private string id2sid(string id)
        {
            StringBuilder sidBuilder = new StringBuilder();
            var guid = Guid.Parse(id);
            foreach (var b in guid.ToByteArray())
            {
                sidBuilder.AppendFormat("\\{0:x2}", b);
            }
            return "0x" + sidBuilder.ToString();
        }

        [FunctionName("AppConfiguration")]
        public async Task<IActionResult> PostAppConfig([HttpTrigger(AuthorizationLevel.Admin, "post", Route = "appconfig")] HttpRequest req, ILogger log)
        {
            log.LogInformation("Received a HTTP trigger request for /api/appconfig.");

            try {
                var jsonBody = await req.ReadAsStringAsync();
                AppConfigModel model = JsonConvert.DeserializeObject<AppConfigModel>(jsonBody);

                ConfigurationClient client = new ConfigurationClient(new Uri(appConfigurationService), new DefaultAzureCredential());
                ConfigurationSetting settingToCreate = new ConfigurationSetting(model.Key, model.Value);
                ConfigurationSetting createdSetting = await client.SetConfigurationSettingAsync(settingToCreate);

                return new JsonResult(createdSetting);
            } catch (Exception exception) {
                return new BadRequestObjectResult(exception.Message);
            }
        }

        [FunctionName("SqlRole")]
        public async Task<IActionResult> PostSqlRole([HttpTrigger(AuthorizationLevel.Admin, "post", Route = "sqlrole")] HttpRequest req, ILogger log)
        {
            log.LogInformation("Received a HTTP trigger request for /api/sqlrole.");

            try {
                var jsonBody = await req.ReadAsStringAsync();
                SqlRoleModel model = JsonConvert.DeserializeObject<SqlRoleModel>(jsonBody);

                string sid = id2sid(model.Id);
                string sql = @"
                    IF NOT EXISTS (
                        SELECT * FROM sys.database_principals WHERE name = N'$ManagedIdentityName'
                    ) 
                    CREATE USER @pIdentityName WITH sid = @pIdentitySid, type = E;

                    IF NOT EXISTS (
                        SELECT * FROM sys.database_principals p 
                        JOIN sys.database_role_members db_datareader_role ON db_datareader_role.member_principal_id = p.principal_id 
                        JOIN sys.database_principals role_names ON role_names.principal_id = db_datareader_role.role_principal_id AND role_names.[name] = 'db_datareader' 
                        WHERE p.[name]=@pIdentityName
                    ) 
                    ALTER ROLE db_datareader ADD MEMBER @pIdentityName;

                    IF NOT EXISTS (
                        SELECT * FROM sys.database_principals p 
                        JOIN sys.database_role_members db_datawriter_role ON db_datawriter_role.member_principal_id = p.principal_id 
                        JOIN sys.database_principals role_names ON role_names.principal_id = db_datawriter_role.role_principal_id AND role_names.[name] = 'db_datawriter' 
                        WHERE p.[name]=@pIdentityName
                    ) 
                    ALTER ROLE db_datawriter ADD MEMBER @pIdentityName;
                ";

                int nRows = -1;
                using (SqlConnection connection = new SqlConnection(sqlConnectionString)) 
                {
                    SqlCommand command = new SqlCommand(sql, connection);
                    command.Parameters.AddWithValue("@pIdentityName", model.Name);
                    command.Parameters.AddWithValue("@pIdentitySid", sid);

                    nRows = command.ExecuteNonQuery();
                }

                return new OkObjectResult($"Executed query - ${nRows} rows affected");
            } catch (Exception exception) {
                return new BadRequestObjectResult(exception.Message);
            }
        }
    }

    public class AppConfigModel
    {
        public string Key { get; set; }
        public string Value { get; set; }
    }

    public class SqlRoleModel
    {
        public string Name { get; set; }
        public string Id { get; set; }
    }
}
