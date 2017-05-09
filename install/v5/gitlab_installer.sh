#!/bin/bash -e

# GITLAB
# Maintainer: @mcpacosy
# App Version: 5.4

# GitLab 5-4-stable installation script

# This script is based on: https://github.com/gitlabhq/gitlabhq/issues/3626
# It has been tested using a clean Ubuntu Server 12.04 LTS installation
# followed by a sudo apt-get update && sudo apt-get -y upgrade && sudo reboot
# Error messages and warnings can be found in gitlab_installer_errors.log.
# The -e switch in the first line stops the script execution if something goes wrong.
# The Apache configuration for the installation under / is based on:
# http://shanetully.com/2012/08/running-gitlab-from-a-subdirectory-on-apache/
# The Apache configuration for the installtion under /gitlab is based on:
# https://gist.github.com/carlosjrcabello/5486422

# TODO
# - add nginx configuration

export DEBIAN_FRONTEND=noninteractive

ERROR_LOG=$(pwd)/gitlab_installer_errors.log

echo "**************************************"
echo "    GitLab + Apache install script    "
echo "**************************************"
echo
echo "WARNING: This script will overwrite the gitlab database if there is a previous installation!"
echo
read -s -p "> MySQL root password: " mysqlpass
echo
read -p "> Postfix server name (hostname: $(hostname)): " postfix_server_name
# TODO currently (2) is NOT implemented
read -p "> Install GitLab under / (1), /gitlab (2) or manual configuration (3) [1/2/3]: " apache_gitlab_root

echo -n > $ERROR_LOG

# Needed to create a unique password non-interactively.
sudo apt-get install -y makepasswd 2>> $ERROR_LOG
# Generate a random gitlab MySQL password
gitlabpass=$(makepasswd --char=16 2>> $ERROR_LOG) 
currentdir=$(pwd)

# Install essentials
essentials=(
    "build-essential"
    "zlib1g-dev"
    "libyaml-dev"
    "libssl-dev"
    "libgdbm-dev"
    "rubygems"
    "ruby-bundler"
    "libreadline-dev"
    "libncurses5-dev"
    "libffi-dev"
    "curl"
    "git-core"
    "openssh-server"
    "redis-server"
    "checkinstall"
    "libxml2-dev"
    "libxslt-dev"
    "libcurl4-openssl-dev"
    "libicu-dev")

# install packages seperately to abort on error
for package in "${essentials[@]}"
do
    sudo apt-get install -y $package 2>> $ERROR_LOG
done

# set configuration values so that the installation can be performed non-interactively
sudo debconf-set-selections <<< "postfix postfix/mailname string $postfix_server_name"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

sudo apt-get install -y postfix

# Install Python
sudo apt-get install -y python python2.7 2>> $ERROR_LOG

# check if symbolic link to /usr/bin/python2 exists
if [[ ! -h /usr/bin/python2 ]]; then sudo ln -s /usr/bin/python /usr/bin/python2 2>> $ERROR_LOG; fi

# Install Ruby
if [[ -d "/tmp/ruby" ]]; then rm -rf /tmp/ruby; fi 2>> $ERROR_LOG
mkdir /tmp/ruby && cd /tmp/ruby 2>> $ERROR_LOG
curl --progress http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p327.tar.gz | tar xz 2>> $ERROR_LOG
cd ruby-1.9.3-p327 2>> $ERROR_LOG
./configure 2>> $ERROR_LOG
make 2>> $ERROR_LOG
sudo make install 2>> $ERROR_LOG

# Install Ruby Bundler
sudo gem install bundler 2>> $ERROR_LOG

# Create git user
sudo adduser --disabled-login --gecos 'GitLab' git 2>> $ERROR_LOG

# Go to home directory
cd /home/git 2>> $ERROR_LOG

# Clone gitlab shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git 2>> $ERROR_LOG
cd gitlab-shell 2>> $ERROR_LOG

# switch to right version for v5.0
sudo -u git -H git checkout v1.1.0 2>> $ERROR_LOG
sudo -u git -H git checkout -b v1.1.0 2>> $ERROR_LOG

sudo -u git -H cp config.yml.example config.yml 2>> $ERROR_LOG

# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
#sudo -u git -H nano config.yml
sudo -u git -H sed -i '5s/.*/gitlab_url: "http:\/\/localhost\/"/' config.yml 2>> $ERROR_LOG

# Do setup
sudo -u git -H ./bin/install 2>> $ERROR_LOG

# NOTE: hard-coded version 5.5 for mysql-server
# set configuration values so that the installation can be performed non-interactively
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password password $mysqlpass"
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password_again password $mysqlpass"

# Install the database packages
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev 2>> $ERROR_LOG

# Create a user for GitLab.
mysql -uroot -p$mysqlpass -e "CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$gitlabpass';" 2>> $ERROR_LOG

# Create the GitLab production database
mysql -uroot -p$mysqlpass -e "CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;" 2>> $ERROR_LOG

# Grant the GitLab user necessary permissopns on the table.
mysql -uroot -p$mysqlpass -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost';" 2>> $ERROR_LOG

# Quit the database session
mysql -uroot -p$mysqlpass -e "\\q;" 2>> $ERROR_LOG

# Try connecting to the new database with the new user
sudo -u git -H mysql -ugitlab -p$gitlabpass -D gitlabhq_production -e "\\q;" 2>> $ERROR_LOG

# We'll install GitLab into home directory of the user "git"
cd /home/git 2>> $ERROR_LOG

# Clone GitLab repository
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab 2>> $ERROR_LOG

# Go to gitlab dir
cd /home/git/gitlab 2>> $ERROR_LOG

# Checkout to stable release
# TODO 5.1/5.2
sudo -u git -H git checkout 5-4-stable 2>> $ERROR_LOG

cd /home/git/gitlab 2>> $ERROR_LOG

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml 2>> $ERROR_LOG

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
#sudo -u git -H nano config/gitlab.yml
sudo -u git -H sed -i '18s/.*/    host: localhost/' config/gitlab.yml 2>> $ERROR_LOG
sudo -u git -H sed -i '19s/.*/    port: 3000/' config/gitlab.yml 2>> $ERROR_LOG

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/ 2>> $ERROR_LOG
sudo chown -R git tmp/ 2>> $ERROR_LOG
sudo chmod -R u+rwX log/ 2>> $ERROR_LOG
sudo chmod -R u+rwX tmp/ 2>> $ERROR_LOG

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites 2>> $ERROR_LOG

# Create directory for pids and make sure GitLab can write to it
sudo -u git -H mkdir tmp/pids/ 2>> $ERROR_LOG
sudo chmod -R u+rwX  tmp/pids/ 2>> $ERROR_LOG

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb 2>> $ERROR_LOG

#sudo nano config/unicorn.rb
sudo -u git -H sed -i '19s/.*/listen "127.0.0.1:3000"  # listen to port 8080 on the loopback interface/' config/unicorn.rb 2>> $ERROR_LOG
sudo -u git -H sed -i '20s/.*/#listen "#{app_dir}\/tmp\/sockets\/gitlab.socket"/' config/unicorn.rb 2>> $ERROR_LOG

# Mysql
sudo -u git cp config/database.yml.mysql config/database.yml 2>> $ERROR_LOG
#sudo nano config/database.yml
sudo -u git -H sed -i "10s/.*/  username: gitlab/" config/database.yml 2>> $ERROR_LOG
sudo -u git -H sed -i "11s/.*/  password: ${gitlabpass}/" config/database.yml 2>> $ERROR_LOG
sudo -u git -H sed -i "24s/.*/  username: gitlab/" config/database.yml 2>> $ERROR_LOG
sudo -u git -H sed -i "25s/.*/  password: ${gitlabpass}/" config/database.yml 2>> $ERROR_LOG

# Charlock Holmes
cd /home/git/gitlab 2>> $ERROR_LOG
sudo gem install charlock_holmes --version '0.6.9' 2>> $ERROR_LOG

# First run
sudo -u git -H bundle install --deployment --without development test postgres 2>> $ERROR_LOG

# Interactive question
# "This will create the necessary database tables and seed the database. You will lose any previous data stored in the database."
# We answer that with yes

echo "yes" | sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production 2>> $ERROR_LOG

# Init scripts
sudo curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlabhq/5-4-stable/lib/support/init.d/gitlab 2>> $ERROR_LOG
sudo chmod +x /etc/init.d/gitlab 2>> $ERROR_LOG

sudo update-rc.d gitlab defaults 21 2>> $ERROR_LOG
#sudo /usr/lib/insserv/insserv gitlab
#echo "sudo service gitlab start" | cat - /etc/rc.local > /tmp/out && sudo mv /tmp/out /etc/rc.local

# Test configuration
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production 2>> $ERROR_LOG

# clean up
rm -rf /tmp/ruby 2>> $ERROR_LOG

# install Apache2
sudo apt-get install -y apache2 2>> $ERROR_LOG

# install passenger
sudo gem install passenger 2>> $ERROR_LOG

# installed packages required by passenger-install-apache2-module
sudo apt-get install -y apache2-threaded-dev
sudo apt-get install -y libapr1-dev
sudo apt-get install -y libaprutil1-dev

# install the Apache passenger module; confirm installation with ENTER; confirm Apache configuration example
output=$(echo -ne "\n\n" | sudo passenger-install-apache2-module 2>> $ERROR_LOG)

VHOST_CONFIG_FILE=/etc/apache2/sites-available/gitlab
(echo -n | sudo tee $VHOST_CONFIG_FILE) 2>> $ERROR_LOG

# passenger-install-apache2-module produces colored output -> we have to get rid of it
escape=$(echo -ne "\e")

(echo $output | grep -o -e "LoadModule.*\.so" -e "PassengerRoot\s[^ $escape]*" -e "PassengerDefaultRuby.*/bin/ruby" | sudo tee -a $VHOST_CONFIG_FILE) 2>> $ERROR_LOG

server_name=$(hostname)

# after the installation test whether GitLab is running
test_link=""

case $apache_gitlab_root in
        "1") # install GitLab under /
        
        (echo "
<VirtualHost *:80>
    ServerName $server_name
    DocumentRoot /home/git/gitlab/public
    <Directory /home/git/gitlab/public>
       Options -MultiViews
    </Directory>
</VirtualHost>" | sudo tee -a $VHOST_CONFIG_FILE) 2>> $ERROR_LOG

        test_link="http://$server_name/"

        ;;
    
        "2") # install GitLab under /gitlab

        # enable the Apache proxy module
        sudo a2enmod proxy

        # write the configuration
        (echo -e "
<VirtualHost *:80>
    ServerName $server_name
    DocumentRoot /home/git/gitlab/public
    ProxyPass /gitlab/ http://$server_name:3000/
    ProxyPassReverse /gitlab/ http://$server_name:3000/
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
</VirtualHost>
            " | sudo tee -a $VHOST_CONFIG_FILE) 2>> $ERROR_LOG
        
        sudo /etc/init.d/apache2 restart

        test_link="http://$server_name/gitlab/"

        ;;

        *) # manual configuration and wrong input

        echo "Manual configuration of Apache selected."

        (echo -e "\n # TODO VirtualHost configuration" | sudo tee -a $VHOST_CONFIG_FILE) 2>> $ERROR_LOG
        
        echo "GitLab won't be running!"
        ;;
esac

sudo a2ensite gitlab 2>> $ERROR_LOG

sudo /etc/init.d/apache2 restart 2>> $ERROR_LOG

if [[ $apache_gitlab_root == "1" || $apache_gitlab_root == "2" ]]; then
    if [[ "$(wget -q -O- $test_link | grep -i -e gitlab -e 'users/sign_in')" != "" ]]; then
        echo "GitLab is running! Installtion complete."
    else
        echo "GitLab is NOT running! Please check gitlab_installer_errors.log."
    fi
fi

echo "Further settings can be added to $VHOST_CONFIG_FILE."