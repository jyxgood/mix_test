# syntax=docker/dockerfile:1

FROM nginx:1.25.3-alpine

ENV S6_STAGE2_HOOK="/init-hook"
# install packages
RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    apache2-utils \
    git \
    logrotate \
    nano \
    openssl \
    php82 \
    php82-ctype \
    php82-curl \
    php82-fileinfo \
    php82-fpm \
    php82-iconv \
    php82-json \
    php82-mbstring \
    php82-openssl \
    php82-phar \
    php82-session \
    php82-simplexml \
    php82-xml \
    php82-xmlwriter \
    php82-zip \
    php82-zlib \
    fontconfig \
    mariadb-client \
    memcached \
    php82-dom \
    php82-gd \
    php82-ldap \
    php82-mysqlnd \
    php82-pdo_mysql \
    php82-pecl-memcached \
    php82-tokenizer \
    qt5-qtbase \
    ttf-freefont && \
  echo "**** configure nginx ****" && \
  echo 'fastcgi_param  HTTP_PROXY         ""; # https://httpoxy.org/' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  PATH_INFO          $fastcgi_path_info; # http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_split_path_info' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name; # https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/#connecting-nginx-to-php-fpm' >> \
    /etc/nginx/fastcgi_params && \
  echo 'fastcgi_param  SERVER_NAME        $host; # Send HTTP_HOST as SERVER_NAME. If HTTP_HOST is blank, send the value of server_name from nginx (default is `_`)' >> \
    /etc/nginx/fastcgi_params && \
  rm -f /etc/nginx/conf.d/stream.conf && \
  rm -f /etc/nginx/http.d/default.conf && \
  echo "**** guarantee correct php version is symlinked ****" && \
  if [ "$(readlink /usr/bin/php)" != "php82" ]; then \
    rm -rf /usr/bin/php && \
    ln -s /usr/bin/php82 /usr/bin/php; \
  fi && \
  echo "**** configure php ****" && \
  sed -i "s#;error_log = log/php82/error.log.*#error_log = /config/log/php/error.log#g" \
    /etc/php82/php-fpm.conf && \
  sed -i "s#user = nobody.*#user = abc#g" \
    /etc/php82/php-fpm.d/www.conf && \
  sed -i "s#group = nobody.*#group = abc#g" \
    /etc/php82/php-fpm.d/www.conf && \
  echo "**** install php composer ****" && \
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')" && \
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")" && \
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then \
      >&2 echo 'ERROR: Invalid installer checksum' && \
      rm composer-setup.php && \
      exit 1; \
  fi && \
  php composer-setup.php --install-dir=/usr/bin && \
  rm composer-setup.php && \
  ln -s /usr/bin/composer.phar /usr/bin/composer && \
  echo "**** fix logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" \
    /etc/logrotate.conf && \
  sed -i 's#/usr/sbin/logrotate /etc/logrotate.conf#/usr/sbin/logrotate /etc/logrotate.conf -s /config/log/logrotate.status#g' \
    /etc/periodic/daily/logrotate && \
  echo "**** configure php-fpm to pass env vars ****" && \
  sed -E -i 's/^;?clear_env ?=.*$/clear_env = no/g' /etc/php82/php-fpm.d/www.conf && \
  grep -qxF 'clear_env = no' /etc/php82/php-fpm.d/www.conf || echo 'clear_env = no' >> /etc/php82/php-fpm.d/www.conf && \
  echo "env[PATH] = /usr/local/bin:/usr/bin:/bin" >> /etc/php82/php-fpm.conf && \
  echo "**** fetch bookstack ****" && \
  mkdir -p\
    /app/www && \
  curl -o \
    /tmp/bookstack.tar.gz -L \
    "https://codeload.github.com/BookStackApp/BookStack/tar.gz/refs/tags/v23.10.4" && \
  tar xf \
    /tmp/bookstack.tar.gz -C \
    /app/www/ --strip-components=1 && \
  echo "**** install composer dependencies ****" && \
  composer install -d /app/www/ && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    $HOME/.cache \
    $HOME/.composer
# add local files
COPY root/ /

# ports and volumes
EXPOSE 80 443