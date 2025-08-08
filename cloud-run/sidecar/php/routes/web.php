<?php

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developped at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Log;

const LOG_FILE = '/shared-volume/logs/app.log';

// Create directory if it doesn't exist
if (!is_dir(dirname(LOG_FILE))) {
    mkdir(dirname(LOG_FILE), 0755, true);
}

function logInfo($message) {
    Log::build([
        'driver' => 'single',
        'path' => LOG_FILE,
    ])->info($message);
}

Route::get('/', function () {
    logInfo('Hello World!');
    return 'Hello World!';
});
