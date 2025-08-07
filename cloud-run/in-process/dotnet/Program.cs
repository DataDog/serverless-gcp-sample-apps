using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog for structured logging with Datadog correlation
builder.Host.UseSerilog((context, config) =>
{
    config.WriteTo.Console(new Serilog.Formatting.Json.JsonFormatter(renderMessage: true));
});

var app = builder.Build();

app.MapGet("/", (ILogger<Program> logger) =>
{
    logger.LogInformation("Hello World!");
    return Results.Ok("Ok");
});
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
app.Urls.Add($"http://*:{port}");

app.Run();
