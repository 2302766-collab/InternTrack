# Use official PHP image
FROM php:8.2-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libjpeg-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip

# Increase upload limits for attachment endpoints.
RUN { \
    echo "file_uploads=On"; \
    echo "upload_max_filesize=20M"; \
    echo "post_max_size=25M"; \
    echo "max_file_uploads=20"; \
} > /usr/local/etc/php/conf.d/uploads.ini

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy project files
COPY . .

# Install Laravel dependencies
RUN composer install

# Expose Laravel development port
EXPOSE 8000

# Run the development bootstrap script, then the PHP built-in server.
CMD ["sh", "docker/start-dev.sh"]
