// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developped at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

package helloworld

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	dd_logrus "github.com/DataDog/dd-trace-go/contrib/sirupsen/logrus/v2"
	"github.com/DataDog/dd-trace-go/v2/ddtrace/tracer"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/sirupsen/logrus"
)

var LOG_FILE = func() string {
	log_file := os.Getenv("DD_SERVERLESS_LOG_PATH")
	if log_file != "" {
		log_file = strings.Replace(log_file, "*.log", "app.log", 1)
	} else {
		log_file = "/shared-volume/logs/app.log"
	}

	fmt.Printf("LOG_FILE: %s\n", log_file)
	return log_file
}()

func init() {
	tracer.Start()

	// Set up logging
	var writers []io.Writer
	writers = append(writers, os.Stdout)

	if os.Getenv("DD_SERVERLESS_LOG_PATH") != "" {
		os.MkdirAll(filepath.Dir(LOG_FILE), 0755)
		logFile, err := os.OpenFile(LOG_FILE, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			logrus.Fatalf("Failed to open log file: %v", err)
		}
		writers = append(writers, logFile)
	}

	logrus.SetOutput(io.MultiWriter(writers...))
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.AddHook(&dd_logrus.DDContextLogHook{})

	functions.HTTP("main", HelloWorld)
}

func HelloWorld(w http.ResponseWriter, r *http.Request) {
	span := tracer.StartSpan("helloworld", tracer.ResourceName("/HelloWorld"))
	defer span.Finish()

	// Use the span context for trace-log correlation
	ctx := tracer.ContextWithSpan(r.Context(), span)
	logrus.WithContext(ctx).Info("Hello World!")

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Hello World!")
}
