#!/bin/sh

# GITLAB
# By: steinkel at gmail.com
# App Version: 6.1 stable https://github.com/gitlabhq/gitlabhq/tree/6-1-stable

# ABOUT
# This script performs a complete installation of Gitlab for ubuntu server 12.04.1 x64:
# * packages update
# * git, postfix etc
# * ruby setup
# * git, gitlab users
# * gitlab-shell fork
# Is should be run as root or sudo user w/o password.
#
# THANKS TO
# @randx for creating the original install script for gitlab 4
# https://www.digitalocean.com/community/articles/how-to-set-up-gitlab-as-your-very-own-private-github-clone
# https://gist.github.com/steinkel/5891151
#
# USAGE
# !IMPORTANT run as root or sudo without prompting password cause script ignore any input.
# sudo apt-get -y install curl && curl https://gist.github.com/steinkel/6855062/raw/1b738b5fab714b53bc37d12c428856a7b252ba39/ubuntu_server_1204.sh | sudo domain_var=gitlab.example.com sh
#

#==
#== 0. FQDN
#==

if [ $domain_var ] ; then
	echo "Installing GitLab for domain: $domain_var"
else
	echo "Please pass domain_var"
	exit
fi

echo "Host localhost
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

echo "Host $domain_var
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

#==
#== 1. Packages
#==
sudo apt-get update
sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl git-core openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

#==
#== 2. RUBY
#==
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd ruby-2.0.0-p247
./configure
make
sudo make install
sudo gem install bundler --no-ri --no-rdoc

# POSTFIX
# Install postfix without prompting.
sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y postfix-policyd-spf-python postfix

#==
#== 3. Users
#==
sudo adduser --disabled-login --gecos 'GitLab' git

#==
#== 4. Gitlab Shell
#==
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
# note, keep the gitlab shell updated here
sudo -u git -H git checkout v1.7.1
sudo -u git -H cp config.yml.example config.yml

# setting up a default configuration
sudo sed -i s%localhost%$domain_var% config.yml

# run install script
sudo -u git -H ./bin/install

#==
#== 5. MySQL
#==
sudo apt-get install -y makepasswd # Needed to create a unique password non-interactively.
mysqlRootPassword=$(makepasswd --char=10) # Generate a random MySQL password
# Note that the lines below creates a cleartext copy of the random password in /var/cache/debconf/passwords.dat
# This file is normally only readable by root and the password will be deleted by the package management system after install.
echo mysql-server mysql-server/root_password password $mysqlRootPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $mysqlRootPassword | sudo debconf-set-selections
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

# setting a gitlab user
gitlabPassword=$(makepasswd --char=10) # Generate a random MySQL password
queryCreateUser="CREATE USER gitlab@localhost IDENTIFIED BY '$gitlabPassword';"
queryCreateDb="CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
queryGrant="GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO gitlab@localhost;"
queryGitlabDb="${queryCreateUser} ${queryCreateDb} ${queryGrant}"
mysql -uroot -p$mysqlRootPassword -e "$queryGitlabDb"

#==
#== 6. GitLab
#==
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/git/gitlab
sudo -u git -H git checkout 6-1-stable

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
sudo -u git -H cp config/database.yml.mysql config/database.yml
sudo sed -i 's/root/gitlab/' config/database.yml # Insert the mysql root password.
sudo sed -i 's/"secure password"/"'$gitlabPassword'"/' config/database.yml # Insert the mysql root password.
sudo sed -i "s/ host: localhost/ host: $domain_var/" config/gitlab.yml
sudo sed -i "s/ssh_host: localhost/ssh_host: $domain_var/" config/gitlab.yml
sudo sed -i "s/notify@localhost/notify@$domain_var/" config/gitlab.yml

# Set some permissions
cd /home/git/gitlab
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX log/
sudo chmod -R u+rwX tmp/
sudo -u git -H mkdir /home/git/gitlab-satellites
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX tmp/pids/
sudo chmod -R u+rwX tmp/sockets/
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX public/uploads
sudo -u git -H chmod o-rwx config/database.yml

# Setup default git parameters
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@$domain_var"
sudo -u git -H git config --global core.autocrlf input

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Setup additional gems
cd /home/git/gitlab
sudo gem install charlock_holmes --version '0.6.9.4'
sudo -u git -H bundle install --deployment --without development test postgres aws

# force rake setup, will overwrite database gitlabhq_production
echo "yes" | sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

# Setup gitlab autorun script
sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab
sudo update-rc.d gitlab defaults 21

#==
#== 7. Nginx
#==
sudo apt-get -y install nginx
cd /home/git/gitlab
sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

sudo sed -i 's/YOUR_SERVER_IP:80/80/' /etc/nginx/sites-available/gitlab # Set Domain
sudo sed -i "s/YOUR_SERVER_FQDN/$domain_var/" /etc/nginx/sites-available/gitlab

# Start all
sudo service gitlab start
sudo service nginx start

# Show info details
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

echo "IMPORTANT: Mysql root password is $mysqlRootPassword"
echo "Gitlab user is admin@local.host"
echo "Gitlab password is 5iveL!fe"
echo "EOT"