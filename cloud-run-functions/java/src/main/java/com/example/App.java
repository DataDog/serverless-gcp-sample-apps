// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developed at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

package com.example;

import com.google.cloud.functions.HttpFunction;
import com.google.cloud.functions.HttpRequest;
import com.google.cloud.functions.HttpResponse;

import datadog.trace.api.Trace;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.BufferedWriter;
import java.io.IOException;

public class App implements HttpFunction {

    static {
        String envLogPath = System.getenv("DD_SERVERLESS_LOG_PATH");
        String resolvedLogPath = (envLogPath != null && !envLogPath.isEmpty())
                ? envLogPath.replace("*.log", "app.log")
                : "/shared-volume/logs/app.log";
        System.setProperty("LOG_FILE", resolvedLogPath);
        System.out.println("LOG_FILE: " + resolvedLogPath);
    }

    private static final Logger logger = LogManager.getLogger(App.class);

    @Override
    @Trace
    public void service(HttpRequest request, HttpResponse response)
            throws IOException {
        logger.info("Hello World!");
        
        BufferedWriter writer = response.getWriter();
        writer.write("Hello World!");
    }
}