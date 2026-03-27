<?php

// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developed at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

function logJson(string $msg): void
{
    $record = [
        'message' => $msg,
        'dd' => [
            'trace_id' => \DDTrace\logs_correlation_trace_id(),
            'span_id'  => \dd_trace_peek_span_id(),
        ],
    ];
    echo json_encode($record) . "\n";
}

\DDTrace\trace_function('main', function (\DDTrace\SpanData $span) {
    $span->resource = 'main';
});

function main(): void
{
    logJson("Hello world!");
}

main();
