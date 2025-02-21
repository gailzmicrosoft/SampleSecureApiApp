using Microsoft.OpenApi.Models;
using RestAPIs.Middleware;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace RestAPIs
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);
            builder.Configuration.AddEnvironmentVariables(); //
            //builder.Configuration.AddCommandLine(args); // Add command line arguments to configuration
            //builder.Configuration.AddUserSecrets<Program>(); // Add user secrets to configuration



            // Load environment-specific appsettings.json
            var environment = builder.Configuration["ENVIRONMENT"];
            if (string.IsNullOrEmpty(environment))
            {
                environment = "Release"; // Default value if ENVIRONMENT is not set
            }

            //only execute below if the environment is development 
            if (environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
            {
                builder.Configuration
               .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
               .AddJsonFile($"appsettings.{environment}.json", optional: false, reloadOnChange: true);
            }
           

            // Add services to the container.
            builder.Services.AddControllers();
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(c =>
            {
                c.AddSecurityDefinition("x-api-key", new OpenApiSecurityScheme
                {
                    Description = "API Key needed to access the endpoints. x-api-key: Your_API_Key",
                    In = ParameterLocation.Header,
                    Name = "x-api-key",
                    Type = SecuritySchemeType.ApiKey,
                    Scheme = "x-api-key-Scheme"
                });

                c.AddSecurityRequirement(new OpenApiSecurityRequirement
                {
                    {
                        new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "x-api-key"
                            },
                            Scheme = "ApiKeyScheme",
                            Name = "x-api-key",
                            In = ParameterLocation.Header
                        },
                        new List<string>()
                    }
                });
            });


            //// Add Application Insights telemetry
            //builder.Services.AddApplicationInsightsTelemetry(options =>
            //{
            //    options.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
            //});

           
            // You need to configure Azure App Configuration with managed identity already for access 
            //var connectionString = builder.Configuration["AppConfig:ConnectionString"]; // This syntax was not allowed in BICEP
            var connectionString = builder.Configuration["AppConfigConnectionString"];
            if (string.IsNullOrEmpty(connectionString))
            {
                throw new ArgumentNullException(nameof(connectionString), "AppConfigConnectionString not set in the configuration.");
            }

            builder.Configuration.AddAzureAppConfiguration(options =>
            {
                options.Connect(connectionString);
            });

            //// If you want to integrate App Configuration with Key Vault 
            //builder.Configuration.AddAzureAppConfiguration(options =>
            //{
            //    options.Connect(connectionString).ConfigureKeyVault(kv =>
            //    {
            //        kv.SetCredential(new DefaultAzureCredential());
            //    });
            //});

            var app = builder.Build();
     
            //always use Swagger. 
            app.UseSwagger();
            //app.UseSwaggerUI(); // removed becasue this method is overriden below
            app.UseSwaggerUI(c =>
            {
                c.SwaggerEndpoint("/swagger/v1/swagger.json", "RestAPIs v1");
                c.RoutePrefix = string.Empty; // Set Swagger UI at the app's root
            });


            app.UseHttpsRedirection();

            app.UseAuthorization();

            app.UseMiddleware<ApiKeyMiddleware>();

            app.MapControllers();

            if (app.Environment.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                //app.UseHsts(); // Enforces the use of HTTPS by adding HSTS headers to responses, enhancing security.
            }

            app.Run();
        }
    }
}
