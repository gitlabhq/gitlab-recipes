#!/bin/sh

# GITLAB
# Maintainer: @randx
# App Version: 4.0

# ABOUT
# This script performs a complete installation of Gitlab for ubuntu server 12.04.1 x64:
# * packages update
# * redis, git, postfix etc
# * ruby setup
# * git, gitlab users
# * gitolite fork
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
sudo apt-get install -y wget curl build-essential checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev zlib1g-dev libicu-dev redis-server openssh-server git-core libyaml-dev


# Python 

# Install Python
sudo apt-get install -y python

# Make sure that Python is 2.x (3.x is not supported at the moment)
python --version

# If it's Python 3 you might need to install Python 2 separately
sudo apt-get install python2.7

# Make sure you can access Python via python2
python2 --version

# If you get a "command not found" error create a link to the python binary
sudo ln -s /usr/bin/python /usr/bin/python2

# POSTFIX
sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y postfix-policyd-spf-python postfix # Install postfix without prompting.


#==
#== 2. RUBY
#==
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p327.tar.gz
tar xfvz ruby-1.9.3-p327.tar.gz
cd ruby-1.9.3-p327
./configure
make
sudo make install
sudo gem install bundler

#==
#== 3. Users
#==
sudo adduser \
  --system \
  --shell /bin/sh \
  --gecos 'Git Version Control' \
  --group \
  --disabled-password \
  --home /home/git \
  git
  
  
sudo adduser --disabled-login --gecos 'GitLab' gitlab

# Add it to the git group
sudo usermod -a -G git gitlab

# Generate the SSH key
sudo -H -u gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

#==
#== 4. Gitolite
#==

cd /home/git
sudo -u git -H git clone -b gl-v304 https://github.com/gitlabhq/gitolite.git /home/git/gitolite
# Add Gitolite scripts to $PATH
sudo -u git -H mkdir /home/git/bin
sudo -u git -H sh -c 'printf "%b\n%b\n" "PATH=\$PATH:/home/git/bin" "export PATH" >> /home/git/.profile'
sudo -u git -H sh -c 'gitolite/install -ln /home/git/bin'

# Copy the gitlab user's (public) SSH key ...
sudo cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
sudo chmod 0444 /home/git/gitlab.pub

# ... and use it as the admin key for the Gitolite setup
sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gitolite setup -pk /home/git/gitlab.pub"

sudo chmod -R ug+rwXs /home/git/repositories/
sudo chown -R git:git /home/git/repositories/

sudo chmod 750 /home/git/.gitolite/
sudo chown -R git:git /home/git/.gitolite/


sudo -u gitlab -H git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
sudo rm -rf /tmp/gitolite-admin


#==
#== 5. MySQL
#==
sudo apt-get install -y makepasswd # Needed to create a unique password non-interactively.
userPassword=$(makepasswd --char=10) # Generate a random MySQL password
# Note that the lines below creates a cleartext copy of the random password in /var/cache/debconf/passwords.dat
# This file is normally only readable by root and the password will be deleted by the package management system after install.
echo mysql-server mysql-server/root_password password $userPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $userPassword | sudo debconf-set-selections
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev

#==
#== 6. GitLab
#==
cd /home/gitlab
sudo -u gitlab -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/gitlab/gitlab
# Checkout v4
sudo -u gitlab -H git checkout 4-0-stable

# Copy the example GitLab config
sudo -u gitlab -H cp config/gitlab.yml.example config/gitlab.yml
sudo -u gitlab -H cp config/database.yml.mysql config/database.yml
sudo sed -i 's/"secure password"/"'$userPassword'"/' /home/gitlab/gitlab/config/database.yml # Insert the mysql root password.
sudo sed -i "s/  host: localhost/  host: $domain_var/" /home/gitlab/gitlab/config/gitlab.yml
sudo sed -i "s/ssh_host: localhost/ssh_host: $domain_var/" /home/gitlab/gitlab/config/gitlab.yml
sudo sed -i "s/notify@localhost/notify@$domain_var/" /home/gitlab/gitlab/config/gitlab.yml

# Copy the example Unicorn config
sudo -u gitlab -H cp config/unicorn.rb.example config/unicorn.rb

cd /home/gitlab/gitlab

sudo gem install charlock_holmes --version '0.6.9'
sudo -u gitlab -H bundle install --deployment --without development postgres test 

sudo -u gitlab -H git config --global user.name "GitLab"
sudo -u gitlab -H git config --global user.email "gitlab@localhost"

sudo cp ./lib/hooks/post-receive /home/git/.gitolite/hooks/common/post-receive
sudo chown git:git /home/git/.gitolite/hooks/common/post-receive

sudo -u gitlab -H bundle exec rake gitlab:app:setup RAILS_ENV=production

sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/4-0-stable/init.d/gitlab -P /etc/init.d/
sudo chmod +x /etc/init.d/gitlab

sudo update-rc.d gitlab defaults 21


#==
#== 7. Nginx
#==
sudo apt-get install -y nginx
sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/4-0-stable/nginx/gitlab -P /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab


sudo sed -i 's/YOUR_SERVER_IP:80/80/' /etc/nginx/sites-available/gitlab # Set Domain
sudo sed -i "s/YOUR_SERVER_FQDN/$domain_var/" /etc/nginx/sites-available/gitlab

# Start all

sudo service gitlab start
sudo service nginx start

