FROM php:5.6-apache
MAINTAINER Sam Stoelinga <sammiestoel@gmail.com>

ENTRYPOINT ["/entrypoint.sh"]

RUN apt-get update && apt-get install nano

# Provide compatibility for images depending on previous versions
RUN ln -s /var/www/html /app

# Update apache2 configuration for drupal
RUN a2enmod rewrite

# Install packages and PHP-extensions
RUN apt-get -q update \
 && DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
	file \
    libfreetype6 \
    libjpeg62 \
    libpng12-0 \
    libpq-dev \
    libx11-6 \
    libxpm4 \
    mysql-client \
    postgresql-client \
 && BUILD_DEPS="libfreetype6-dev libjpeg62-turbo-dev libmcrypt-dev libpng12-dev libxpm-dev re2c zlib1g-dev"; \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install $BUILD_DEPS \
 && docker-php-ext-configure gd \
        --with-jpeg-dir=/usr/lib/x86_64-linux-gnu --with-png-dir=/usr/lib/x86_64-linux-gnu \
        --with-xpm-dir=/usr/lib/x86_64-linux-gnu --with-freetype-dir=/usr/lib/x86_64-linux-gnu \
 && docker-php-ext-install gd mbstring pdo_mysql pdo_pgsql zip \
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_DEPS \
 && rm -rf /var/lib/apt/lists/* \
 && pecl install uploadprogress

# Download Drupal from ftp.drupal.org
ENV DRUPAL_VERSION=7.41
ENV DRUPAL_TARBALL_MD5=7636e75e8be213455b4ac7911ce5801f

WORKDIR /var/www/html

# Update aptitude with new repo
RUN apt-get update

# Install software
RUN apt-get install -y git
# Make ssh dir
RUN mkdir /root/.ssh/

# Copy over private key, and set permissions
ADD ssh/id_rsa /root/.ssh/id_rsa
ADD ssh/config ssh/config
WORKDIR /root/.ssh/
RUN chmod 600 *


# Create known_hosts
RUN touch /root/.ssh/known_hosts
# Add bitbuckets key
RUN ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts
RUN ssh-keygen -R bitbucket.com

ARG APP_REPO=local
ENV APP_REPO ${APP_REPO}

WORKDIR /var/www/html
RUN rm * -rf \
&& git clone ${APP_REPO} . \
&& chown -R www-data:www-data *

WORKDIR /var/www/html
RUN ls

# Install composer and drush by using composer
ENV COMPOSER_BIN_DIR=/usr/local/bin
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
 && composer global require drush/drush:7.* \
 && drush cc drush \
 && mkdir /etc/drush && echo "<?php\n\$options['yes'] = TRUE;\n\$options['v'] = TRUE;\n" > /etc/drush/drushrc.php

# Add PHP-settings
ADD php-conf.d/ $PHP_INI_DIR/conf.d/

# copy sites/default's defaults
WORKDIR /var/www/html
ADD sites/ sites/
RUN ls
# Add README.md, entrypoint-script and scripts-folder
ADD entrypoint.sh README.md  /
ADD /scripts/ /scripts/
