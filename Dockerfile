FROM lscr.io/linuxserver/webtop:amd64-arch-i3

ARG db_name=auth
ARG tz_country=America
ARG tz_city=New_York
ARG ci_subdir=sub
ARG ci_baseurl=http://localhost
ARG ci_environment=development

ENV TITLE="Arch dwm"

# Install apps
RUN curl -O https://download.sublimetext.com/sublimehq-pub.gpg && sudo pacman-key --add sublimehq-pub.gpg && sudo pacman-key --lsign-key 8A8F901A && rm sublimehq-pub.gpg
RUN echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf
RUN yes | pacman -Syu vivaldi sublime-text fuse wget nano git composer php php-fpm php-intl php-sqlite

# Make/Install suckless apps
RUN git clone https://git.suckless.org/dwm
RUN cd dwm && make clean install
RUN rm -rf dwm
RUN git clone https://git.suckless.org/dmenu
RUN cd dmenu && make clean install
RUN rm -rf dmenu
RUN git clone https://git.suckless.org/st
RUN cd st && make clean install
RUN rm -rf st

# Install wallpaper
RUN wget https://github.com/grimpirate/SVGWall/releases/latest/download/SVGWall-x86_64.AppImage
RUN wget https://raw.githubusercontent.com/grimpirate/SVGWall/refs/heads/main/svg.js
RUN chmod 0755 SVGWall-x86_64.AppImage
#RUN ./SVGWall-x86_64.AppImage --appimage-extract
#RUN chmod 0755 squashfs-root/AppRun
#RUN mv squashfs-root svg.js /home
RUN mv SVGWall-x86_64.AppImage svg.js /home
#RUN rm ./SVGWall-x86_64.AppImage

# Start DWM as window manager
RUN sed -i 's/\/usr\/bin\/i3/sudo php-fpm -D\nsleep 10s \&\& \/home\/SVGWall-x86_64.AppImage -j=\/home\/svg.js \&\n\/usr\/local\/bin\/dwm/' /defaults/startwm.sh

# Modify cursor theme
RUN echo '' > config/.Xresources

# Cleanup
RUN yes | pacman -Rsnu i3 chromium xfce4-terminal xterm

# <CodeIgniter 4 Default Setup>

ADD nginx.conf /etc/nginx/nginx.conf

RUN sed -i "s/;extension=intl/extension=intl/" /etc/php/php.ini
RUN sed -i "s/;extension=sqlite/extension=sqlite/" /etc/php/php.ini

WORKDIR /usr/share/nginx/html

# Create subdirectory
RUN rm -rf *
RUN mkdir $ci_subdir

# Composer install CodeIgniter 4 framework
RUN composer require codeigniter4/framework

### MODIFYING VENDOR FILES DIRECTLY IS DANGEROUS!!! ###

# Disable Session Handler info message
RUN sed -i "s/\$this->logger->info/\/\/\$this->logger->info/" vendor/codeigniter4/framework/system/Session/Session.php

### MODIFYING VENDOR FILES DIRECTLY IS DANGEROUS!!! ###

# Copy files from framework into subdirectory
RUN cp -R vendor/codeigniter4/framework/app $ci_subdir/.
RUN cp -R vendor/codeigniter4/framework/public $ci_subdir/.

# Use writable at the framework level rather than subdirectory level
RUN cp -R vendor/codeigniter4/framework/writable .

# Copy spark and .env file into subdirectory (ignoring phpunit.xml.dist)
RUN cp vendor/codeigniter4/framework/env $ci_subdir/.env
RUN cp vendor/codeigniter4/framework/spark $ci_subdir/.

# Modify default app paths to be one level higher
RUN sed -i "s/\/..\/..\/system/\/..\/..\/..\/vendor\/codeigniter4\/framework\/system/" $ci_subdir/app/Config/Paths.php
RUN sed -i "s/\/..\/..\/writable/\/..\/..\/..\/writable/" $ci_subdir/app/Config/Paths.php
RUN sed -i "s/\/..\/..\/tests/\/..\/..\/..\/tests/" $ci_subdir/app/Config/Paths.php

# Modify composer path to be one level higher
RUN sed -i "s/vendor\/autoload.php/..\/vendor\/autoload.php/" $ci_subdir/app/Config/Constants.php

# Change environment to development
RUN sed -i "s/# CI_ENVIRONMENT = production/CI_ENVIRONMENT = ${ci_environment}/" $ci_subdir/.env

# Set project minimum-stability to dev
RUN composer config minimum-stability dev
RUN composer config prefer-stable true

# Composer install shield (for user administration)
RUN composer require codeigniter4/shield:dev-develop

# </CodeIgniter 4 Default Setup>

# <Custom Site Setup>

# Copy all environment variables to .env file
RUN echo "docker.db_name=${db_name}.db">> $ci_subdir/.env
RUN echo "docker.tz_country=${tz_country}">> $ci_subdir/.env
RUN echo "docker.tz_city=${tz_city}">> $ci_subdir/.env
RUN echo "docker.ci_subdir=${ci_subdir}">> $ci_subdir/.env
RUN echo "docker.ci_baseurl=${ci_baseurl}">> $ci_subdir/.env

# Copy our custom site logic
ADD app $ci_subdir/app

# Create SQLite database(s)
RUN php $ci_subdir/spark db:create $db_name --ext db

# Setup shield using spark and answer yes to migration question
RUN yes | php $ci_subdir/spark shield:setup

# Post setup clean up
RUN rm -rf $ci_subdir/public/favicon.ico

RUN chmod -R 0777 /usr/share/nginx/html/writable;

# </Custom Site Setup>