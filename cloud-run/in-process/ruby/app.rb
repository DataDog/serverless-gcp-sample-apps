require 'sinatra'
require 'logger'
require 'datadog/auto_instrument'

Datadog.configure do |c|
  # Add additional configuration here.
  # Activate integrations, change tracer settings, etc...
end

set :environment, :production
set :port, 8080
set :bind, '0.0.0.0'

logger = Logger.new(STDOUT)
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity}: [#{Datadog::Tracing.log_correlation}] #{msg}\n"
end

get '/' do
  logger.info "A\nB\nC\nD"
  'Hello World!'
end
