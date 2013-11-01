#!/bin/sh

# GITLAB
# Maintainer: @randx
# Updated by: @cgorman
# App Version: 6.2

# ABOUT
# This script performs a complete installation of Gitlab 6.2 for ubuntu server 12.04.1 x64:
# * packages update
# * redis, git, postfix etc
# * ruby setup
# * git user
# * gitlab-shell
# Is should be run as root or sudo user w/o password. 
#
# USAGE
# !IMPORTANT run as root or sudo without prompting password cause script ignore any input.
# curl https://raw.github.com/gitlabhq/gitlab-recipes/master/install/v4/ubuntu_server_1204.sh | sudo domain_var=gitlab.example.com sh
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
sudo apt-get install -y wget curl build-essential checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev zlib1g-dev libicu-dev redis-server openssh-server git-core libyaml-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev logrotate


# Python 

# Install Python
sudo apt-get install -y python

# Make sure that Python is 2.x (3.x is not supported at the moment)
python --version

# If it's Python 3 you might need to install Python 2 separately
sudo apt-get install -y python2.7

# Make sure you can access Python via python2
python2 --version

# If you get a "command not found" error create a link to the python binary
sudo ln -s /usr/bin/python /usr/bin/python2

# For reStructuredText markup language support install required package:
sudo apt-get install -y python-docutils

# POSTFIX
sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y postfix-policyd-spf-python postfix # Install postfix without prompting.


#==
#== 2. RUBY
#==

#Remove Ruby 1.8 if present
sudo apt-get remove ruby1.8

wget http://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz
tar xfvz ruby-2.0.0-p247.tar.gz
cd ruby-2.0.0-p247
./configure --disable-install-rdoc
make
sudo make install
# Install the Bundler Gem
sudo gem install bundler --no-ri --no-rdoc

#==
#== 3. User
#==
  
sudo adduser --disabled-login --gecos 'GitLab' git

#==
#== 4. GitLab shell
#==
cd /home/git

# Clone GitLab shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git

cd gitlab-shell

# Switch to rigt version
sudo -u git -H git checkout v1.7.1

sudo -u git -H cp config.yml.example config.yml

# Edit config and replace gitlab_url with fqdn

sudo sed -i 's@gitlab_url: "http://localhost/"@gitlab_url: "http://'$domain_var'/"'@ config.yml

# Do setup
sudo -u git -H ./bin/install


#==
#== 5. MySQL
#==
cd ~
sudo apt-get install -y makepasswd # Needed to create a unique password non-interactively.
userPassword=$(makepasswd --char=10) # Generate a random MySQL password
# Note that the lines below creates a cleartext copy of the random password in /var/cache/debconf/passwords.dat
# This file is normally only readable by root and the password will be deleted by the package management system after install.
echo mysql-server mysql-server/root_password password $userPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $userPassword | sudo debconf-set-selections

sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

password2=$(makepasswd --char=10)
echo "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$password2';" > user.sql
echo "CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;" > db.sql
echo "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost';" > grant.sql
mysql -u root -p$userPassword < user.sql
mysql -u root -p$userPassword < db.sql
mysql -u root -p$userPassword < grant.sql

rm user.sql grant.sql db.sql



#==
#== 6. GitLab
#==
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/git/gitlab
# Checkout v6.2
sudo -u git -H git checkout 6-2-stable

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
sudo -u git -H cp config/database.yml.mysql config/database.yml
sudo sed -i 's/"secure password"/"'$password2'"/' /home/git/gitlab/config/database.yml # Insert the mysql gitlab password.
sudo -u git -H chmod o-rwx config/database.yml
sudo sed -i "s/  host: localhost/  host: $domain_var/" /home/git/gitlab/config/gitlab.yml
sudo sed -i "s/ssh_host: localhost/ssh_host: $domain_var/" /home/git/gitlab/config/gitlab.yml
sudo sed -i "s/notify@localhost/notify@$domain_var/" /home/git/gitlab/config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX  log/
sudo chmod -R u+rwX  tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directories for sockets/pids and make sure GitLab can write to them
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
sudo chmod -R u+rwX  tmp/pids/
sudo chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
sudo -u git -H mkdir public/uploads
sudo chmod -R u+rwX  public/uploads

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

cd /home/git/gitlab



# Copy the example Rack attack config
sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb


# Enable rack attack middleware
# Find and uncomment the line 'config.middleware.use Rack::Attack' 
sudo -u git -H sed -i s@'# config.middleware.use Rack::Attack@config.middleware.use Rack::Attack'@ /home/git/gitlab/config/application.rb

sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@localhost"
sudo -u git -H git config --global core.autocrlf input

cd /home/git/gitlab
sudo gem install charlock_holmes --version '0.6.9.4'
sudo -u git -H bundle install --deployment --without development postgres test aws

# Task requires input to continue
echo "yes" | sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production


sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab

sudo update-rc.d gitlab defaults 21

# Set up logrotate
sudo cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

# Start instance
sudo service gitlab start


#==
#== 7. Nginx
#==
sudo apt-get install -y nginx
sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab


#sudo sed -i 's/YOUR_SERVER_IP:80/80/' /etc/nginx/sites-available/gitlab # Set Domain
sudo sed -i "s/YOUR_SERVER_FQDN/$domain_var/" /etc/nginx/sites-available/gitlab

# Start all

sudo service nginx start

