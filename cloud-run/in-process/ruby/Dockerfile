FROM ruby:3.3

WORKDIR /app

COPY Gemfile .
RUN bundle install

ENV PORT=8080
EXPOSE 8080

COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init

COPY . .

ARG GCP_PROJECT_NAME
ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=${GCP_PROJECT_NAME}
ENV DD_SOURCE=ruby
ENV DD_LOGS_ENABLED=true

ENTRYPOINT ["/app/datadog-init"]
CMD ["bundle", "exec", "ruby", "app.rb"]
