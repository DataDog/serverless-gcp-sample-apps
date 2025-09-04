// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developped at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

using Google.Cloud.Functions.Framework;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;
using System.Threading.Tasks;
using Datadog.Trace;
using Serilog;
using Serilog.Formatting.Json;

namespace Main;

public class Function : IHttpFunction
{
    private static readonly string LOG_FILE;

    static Function()
    {
        var loggerConfig = new LoggerConfiguration()
            .WriteTo.Console(new JsonFormatter(renderMessage: true));

        // Only add the file appender if the environment variable is set
        var rawLogPath = Environment.GetEnvironmentVariable("DD_SERVERLESS_LOG_PATH");
        if (!string.IsNullOrEmpty(rawLogPath))
        {
            LOG_FILE = rawLogPath.Replace("*.log", "app.log");
            Console.WriteLine($"LOG_FILE: {LOG_FILE}");
            Directory.CreateDirectory(Path.GetDirectoryName(LOG_FILE)!);
            loggerConfig.WriteTo.File(new JsonFormatter(renderMessage: true), LOG_FILE);
        }

        Log.Logger = loggerConfig.CreateLogger();
    }

    public async Task HandleAsync(HttpContext context)
    {
        using (var scope = Tracer.Instance.StartActive("hello-world-function"))
        {
            Log.Information("Hello World!");
            await context.Response.WriteAsync("Hello World!");
        }
    }
}
