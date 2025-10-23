// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developed at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

package main

import (
	"context"

	dd_logrus "github.com/DataDog/dd-trace-go/contrib/sirupsen/logrus/v2"
	"github.com/DataDog/dd-trace-go/v2/ddtrace/tracer"
	"github.com/sirupsen/logrus"
)

func main() {
	tracer.Start()
	defer tracer.Stop()
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.AddHook(&dd_logrus.DDContextLogHook{})

	span := tracer.StartSpan("my_job")
	defer span.Finish()

	ctx := tracer.ContextWithSpan(context.Background(), span)
	logrus.WithContext(ctx).Info("Hello world!")
}
