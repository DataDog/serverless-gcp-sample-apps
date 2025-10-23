// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developed at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

package com.example;

import datadog.trace.api.Trace;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class App {

    private static final Logger logger = LogManager.getLogger(App.class);

    @Trace
    public static void main(String[] args) {
        logger.info("Hello world!");
    }
}
