
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Extensions.Configuration;

namespace RestAPIs.Middleware
{
    public class ApiKeyMiddleware
    {
        private readonly RequestDelegate _next;
        private const string APIKEYNAME = "x-api-key";
        private readonly IConfiguration _configuration;

        public ApiKeyMiddleware(RequestDelegate next, IConfiguration configuration)
        {
            _next = next;
            _configuration = configuration;
        }


        public async Task InvokeAsync(HttpContext context)
        {
            if (!context.Request.Headers.TryGetValue(APIKEYNAME, out var extractedApiKey))
            {
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Api Key x-api-key was not provided.");
                return;
            }

            ///************************************* appsettings.json *************************/
            //var appSettings = context.RequestServices.GetRequiredService<IConfiguration>();
            //var apiKey = appSettings.GetValue<string>(APIKEYNAME);

            /******************************** App Configuration *******************/
            // Retrieve the API key from the configuration
            var apiKey = _configuration.GetValue<string>(APIKEYNAME);


            if (apiKey == null || (!apiKey.Equals(extractedApiKey)))
            {
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Unauthorized client.");
                return;
            }

            await _next(context);
        }
    }

}