FROM php:8.4-apache

WORKDIR /var/www/html

# Install system dependencies and Composer
RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create Laravel project
RUN composer create-project laravel/laravel . --no-dev

# Install Datadog tracer
RUN curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-setup.php \
    && php datadog-setup.php --php-bin=all

ENV PORT=8080
EXPOSE 8080

# Copy serverless-init
COPY --from=datadog/serverless-init:1 /datadog-init /app/datadog-init

# Copy our custom routes (will overwrite Laravel default)
COPY routes/ routes/

# Set up Apache configuration for port 8080 and document root
RUN sed -i 's/80/${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf \
    && sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

# Enable Apache rewrite module
RUN a2enmod rewrite

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache

ARG GCP_PROJECT_NAME
ENV DD_SITE=datadoghq.com
ENV DD_SERVICE=${GCP_PROJECT_NAME}
ENV DD_SOURCE=php
ENV DD_LOGS_ENABLED=true
ENV DD_LOGS_INJECTION=true
ENV LOG_CHANNEL=stderr

ENTRYPOINT ["/app/datadog-init"]
CMD ["apache2-foreground"]
