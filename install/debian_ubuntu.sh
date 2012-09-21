#!/bin/sh

# GITLAB
# Maintainer: @randx
# App Version: 2.9

# ABOUT
# This script performs only PARTIAL installation of Gitlab:
# * packages update
# * redis, git, postfix etc
# * ruby setup
# * git, gitlab users
# * gitolite fork
# Is should be run as root.

apt-get -y update
apt-get -y upgrade
apt-get -y install sudo

apt-get install -y git git-core wget curl gcc checkinstall libxml2-dev libxslt-dev sqlite3 libsqlite3-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev libmysql++-dev make build-essential zlib1g-dev libicu-dev redis-server openssh-server python-dev python-pip libyaml-dev postfix

wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p194.tar.gz
tar xfvz ruby-1.9.3-p194.tar.gz
cd ruby-1.9.3-p194
./configure
make
make install

adduser \
  --system \
  --shell /bin/sh \
  --gecos 'git version control' \
  --group \
  --disabled-password \
  --home /home/git \
  git

adduser --disabled-login --gecos 'gitlab system' gitlab

usermod -a -G git gitlab

sudo -H -u gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

cd /home/git
sudo -H -u git git clone git://github.com/gitlabhq/gitolite /home/git/gitolite

sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; /home/git/gitolite/src/gl-system-install"
cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
chmod 777 /home/git/gitlab.pub

sudo -u git -H sed -i 's/0077/0007/g' /home/git/share/gitolite/conf/example.gitolite.rc
sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gl-setup -q /home/git/gitlab.pub"

chmod -R g+rwX /home/git/repositories/
chown -R git:git /home/git/repositories/

sudo -u git -H sh -c 'echo -e "Host localhost\n\tStrictHostKeyChecking no\n" >> ~gitlab/.ssh/config'

sudo -u gitlab -H git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
rm -rf /tmp/gitolite-admin
