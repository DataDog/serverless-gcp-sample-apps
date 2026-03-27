# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

require 'logger'
require 'datadog/auto_instrument'

logger = Logger.new(STDOUT)
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: [#{Datadog::Tracing.log_correlation}] #{msg}\n"
end

Datadog::Tracing.trace('my_job') do
  logger.info "Hello world!"
end
