// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache 2.0 License.

// This product includes software developped at
// Datadog (https://www.datadoghq.com/)
// Copyright 2025-present Datadog, Inc.

package main

import (
	"fmt"
	"net/http"

	httptrace "github.com/DataDog/dd-trace-go/contrib/net/http/v2"
	dd_logrus "github.com/DataDog/dd-trace-go/contrib/sirupsen/logrus/v2"
	"github.com/DataDog/dd-trace-go/v2/ddtrace/tracer"
	"github.com/sirupsen/logrus"
)

const PORT = "8080"

func main() {
	tracer.Start()
	defer tracer.Stop()
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.AddHook(&dd_logrus.DDContextLogHook{})

	mux := httptrace.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Use the request context for trace-log correlation
		ctx := r.Context()
		logrus.WithContext(ctx).Info("Hello World!")

		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "Hello World!")
	})

	logrus.Infof("Starting server on port %s", PORT)

	if err := http.ListenAndServe(":"+PORT, mux); err != nil {
		logrus.Fatalf("Server failed to start: %v", err)
	}
}
