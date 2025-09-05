# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

require 'functions_framework'
require 'logger'
require 'datadog/auto_instrument'
require 'fileutils'

LOG_FILE = (ENV['DD_SERVERLESS_LOG_PATH']&.gsub('*.log', 'app.log')) || '/shared-volume/logs/app.log'
puts "LOG_FILE: #{LOG_FILE}"

# Create log directory if it doesn't exist
begin
  FileUtils.mkdir_p(File.dirname(LOG_FILE))
rescue Errno::EACCES => e
  puts "Warning: Could not create log directory #{File.dirname(LOG_FILE)}: #{e.message}"
  puts "Using fallback log path"
  LOG_FILE = '/tmp/app.log'
end

# Configure Datadog
Datadog.configure do |c|
  # Add additional configuration here.
  # Activate integrations, change tracer settings, etc...
end

# Create logger that writes to file in shared volume
logger = Logger.new(LOG_FILE)
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: [#{Datadog::Tracing.log_correlation}] #{msg}\n"
end

FunctionsFramework.http 'main' do |request|
  Datadog::Tracing.trace('hello-world-function') do |span|
    span.set_tag('function.name', 'ruby-cloud-function')
    span.set_tag('function.runtime', 'ruby')
    
    logger.info "Hello World!"
    'Hello World!'
  end
end
