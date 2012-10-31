#!/bin/sh

# GITLAB
# Maintainer: @randx
# App Version: 3.0

# ABOUT
# This script performs a PARTIAL installation of Gitlab, installing all
# the required packages to get gitolite up and running.
# It requires root permissions

# INSTALL PACKAGES

# update and sudo
apt-get update
apt-get upgrade
apt-get install sudo

# utilities
apt-get install -y wget curl gcc checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev libmysql++-dev make build-essential zlib1g-dev libicu-dev redis-server openssh-server git-core python-dev python-pip libyaml-dev postfix

# SQLite
apt-get install -y sqlite3 libsqlite3-dev

# postgres
apt-get install -y postgres libpq-dev

# MySQL
apt-get install -y mysql-server mysql-client libmysqlclient-dev

# INSTALL RUBY
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p194.tar.gz
tar xfvz ruby-1.9.3-p194.tar.gz
cd ruby-1.9.3-p194
./configure
make
make install

# INSTALL GITOLITE
adduser \
  --system \
  --shell /bin/sh \
  --gecos 'git version control' \
  --group \
  --disabled-password \
  --home /home/git \
  git

# Create gitlab user
adduser --disabled-login --gecos 'gitlab system' gitlab

usermod -a -G git gitlab
usermod -a -G gitlab git

# Generate key
sudo -u gitlab -H ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

# Clone and install
sudo -u git -H git clone git://github.com/gitlabhq/gitolite /home/git/gitolite
cd /home/git
sudo -u git -H mkdir bin
sudo -u git sh -c 'echo -e "PATH=\$PATH:/home/git/bin\nexport PATH" >> /home/git/.profile'
sudo -u git sh -c 'gitolite/install -ln /home/git/bin'

cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
chmod 0444 /home/git/gitlab.pub

sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gitolite setup -pk /home/git/gitlab.pub"

# Setup permissions
chmod -R g+rwX /home/git/repositories/
chown -R git:git /home/git/repositories/

sudo -u gitlab -H git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
rm -rf /tmp/gitolite-admin