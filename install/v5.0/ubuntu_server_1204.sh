#!/bin/sh

# GITLAB
# Maintainer: @michaelvanderheeren
# App Version: 5.0

# ABOUT
# This script performs a complete installation of Gitlab for ubuntu server 12.04
# With mysql server
#
# USAGE
# !IMPORTANT do not run as root! It will ask you password when needed


echo "********************************"
echo "    GitLab Install script"
echo "********************************"
read -s -p "> MySQL root pass: " mysqlpass

# Needed to create a unique password non-interactively.
sudo apt-get install -y makepasswd 
# Generate a random gitlab MySQL password
gitlabpass=$(makepasswd --char=16) 
currentdir=$(pwd)

# Install essentials
sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev
sudo apt-get install -y libreadline-dev libncurses5-dev libffi-dev curl git-core 
sudo apt-get install -y openssh-server redis-server postfix checkinstall libxml2-dev 
sudo apt-get install -y libxslt-dev libcurl4-openssl-dev libicu-dev

# Install Python
sudo apt-get install -y python python2.7
sudo ln -s /usr/bin/python /usr/bin/python2

# Install Ruby
rm -rf /tmp/ruby
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p327.tar.gz | tar xz
cd ruby-1.9.3-p327
./configure
make
sudo make install

# Install Ruby Bundler
sudo gem install bundler

# Create git user
sudo adduser --disabled-login --gecos 'GitLab' git

# Go to home directory
cd /home/git

# Clone gitlab shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell

# switch to right version for v5.0
sudo -u git -H git checkout v1.1.0
sudo -u git -H git checkout -b v1.1.0

sudo -u git -H cp config.yml.example config.yml

# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
#sudo -u git -H nano config.yml
sudo -u git -H sed -i '5s/.*/gitlab_url: "http:\/\/localhost\/"/' config.yml

# Do setup
sudo -u git -H ./bin/install

# Install the database packages
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

# Create a user for GitLab.
mysql -uroot -p$mysqlpass -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlabpass';"

# Create the GitLab production database
mysql -uroot -p$mysqlpass -e "CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;"

# Grant the GitLab user necessary permissopns on the table.
mysql -uroot -p$mysqlpass -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost';"

# Quit the database session
mysql -uroot -p$mysqlpass -e "\\q;"

# Try connecting to the new database with the new user
sudo -u git -H mysql -ugitlab -p$gitlabpass -D gitlabhq_production

# We'll install GitLab into home directory of the user "git"
cd /home/git

# Clone GitLab repository
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab

# Go to gitlab dir
cd /home/git/gitlab

# Checkout to stable release
sudo -u git -H git checkout 5-0-stable

cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
#sudo -u git -H nano config/gitlab.yml
sudo -u git -H sed -i '18s/.*/    host: localhost/' config/gitlab.yml
sudo -u git -H sed -i '19s/.*/    port: 3000/' config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX log/
sudo chmod -R u+rwX tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directory for pids and make sure GitLab can write to it
sudo -u git -H mkdir tmp/pids/
sudo chmod -R u+rwX  tmp/pids/

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb
#sudo nano config/unicorn.rb
sudo -u git -H sed -i '19s/.*/listen "127.0.0.1:3000"  # listen to port 8080 on the loopback interface/' config/unicorn.rb
sudo -u git -H sed -i '20s/.*/#listen "#{app_dir}\/tmp\/sockets\/gitlab.socket"/' config/unicorn.rb

# Mysql
sudo -u git cp config/database.yml.mysql config/database.yml
#sudo nano config/database.yml
sudo -u git -H sed -i "10s/.*/  username: gitlab/" config/database.yml
sudo -u git -H sed -i "11s/.*/  password: ${gitlabpass}/" config/database.yml
sudo -u git -H sed -i "24s/.*/  username: gitlab/" config/database.yml
sudo -u git -H sed -i "25s/.*/  password: ${gitlabpass}/" config/database.yml

# Charlock Holmes
cd /home/git/gitlab
sudo gem install charlock_holmes --version '0.6.9'

# First run
sudo -u git -H bundle install --deployment --without development test postgres
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

# Init scripts
sudo curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/5-0-stable/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab

sudo update-rc.d gitlab defaults 21
#sudo /usr/lib/insserv/insserv gitlab
#echo "sudo service gitlab start" | cat - /etc/rc.local > /tmp/out && sudo mv /tmp/out /etc/rc.local

# Test configuration
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

echo "********************************"
echo "finished, you can configure nginx or apache"
echo "needs to point to 127.0.0.1:3000 with proxy"
echo "********************************"