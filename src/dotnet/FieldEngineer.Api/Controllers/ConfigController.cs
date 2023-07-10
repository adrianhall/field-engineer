using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;

namespace FieldEngineer.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ConfigController : ControllerBase
    {
        public ConfigController(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        [HttpGet]
        public ActionResult<JToken> GetConfiguration()
        {
            return new OkObjectResult(Serialize(Configuration));
        }

        private JToken Serialize(IConfiguration config)
        {
            JObject obj = new JObject();
            foreach (var child in config.GetChildren())
            {
                obj.Add(child.Key, Serialize(child));
            }
            if (!obj.HasValues && config is IConfigurationSection section)
            {
                return new JValue(section.Value);
            }
            return obj;
        }
    }
}
