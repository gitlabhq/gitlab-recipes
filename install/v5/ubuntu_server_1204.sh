# @title GitLab v5 Ubuntu/Debian Installer
# ------------------------------------------------------------------------------------------
# @author Myles McNamara
# @date 7.17.2013
# @version 1.0
# @source https://github.com/tripflex/gitlab-recipes/
# ------------------------------------------------------------------------------------------
# @usage ./ubuntu_server_1204.sh domain.com
# ------------------------------------------------------------------------------------------
# @copyright Copyright (C) 2013 Myles McNamara
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------------------------

#  ========================================
#  = Required Script Configuration Values =
#  ========================================
gitlab_release=5-3-stable

#  ==============================
#  = Optional apt-get arguments =
#  ==============================
#  -s = simulate
#  -y = yes (no prompt)
#  -q = quiet
#  -qq = even more quiet (also implies -y, do not use with -s)
aptget_arguments="-qq"

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [[ $1 == -* ]]; then
   echo "Usage: $0 domain.com" >&2
   exit
fi

clear
echo "### Feeding the rabbit, here we go..."
if [ "$#" -lt 1 ]; then
  echo "=== Domain was not specified, using localhost as default"
  domain_var=localhost
fi

echo "=== Installing GitLab v5 (Release: $gitlab_release) for $domain_var"

echo "Host localhost
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

echo "Host $domain_var
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config


#  ====================
#  = Install Packages =
#  ====================
#  
sudo apt-get update
sudo apt-get install $aptget_arguments build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl wget git-core openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

#  =======================
#  = Python Installation =
#  =======================
#  
sudo apt-get install $aptget_arguments python

# Make sure that Python is 2.x (3.x is not supported at the moment)
python --version

# If it's Python 3 you might need to install Python 2 separately
sudo apt-get install $aptget_arguments python2.7

# Make sure you can access Python via python2
python2 --version

# If you get a "command not found" error create a link to the python binary
sudo ln -s /usr/bin/python /usr/bin/python2

#  ===================
#  = Postfix Install =
#  ===================
#  
sudo DEBIAN_FRONTEND='noninteractive' apt-get install $aptget_arguments postfix-policyd-spf-python postfix # Install postfix without prompting.


#  =====================
#  = Ruby Installation =
#  =====================
#  
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd ruby-2.0.0-p247
./configure
make
sudo make install

# Bundler Gem
sudo gem install bundler --no-ri --no-rdoc

#  ================
#  = System Users =
#  ================
#  
# Create system git user for GitLab
sudo adduser --disabled-login --gecos 'GitLab' git

#  =============================
#  = GitLab Shell Installation =
#  =============================
#  
# Go to home directory
cd /home/git

# Clone gitlab shell
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
# switch to right version
sudo -u git -H git checkout v1.4.0
# copy example config to config.yml
sudo -u git -H cp config.yml.example config.yml

# Edit config and replace gitlab_url
sudo -u git -H sed -i 's/localhost/$domain_var/g' config.yml

# Do setup
sudo -u git -H ./bin/install

#  ======================
#  = MySQL Installation =
#  ======================
#  
sudo apt-get install $aptget_arguments makepasswd # Needed to create a unique password non-interactively.
mysqlPassword=$(makepasswd --char=10) # Generate a random MySQL password
# Note that the lines below creates a cleartext copy of the random password in /var/cache/debconf/passwords.dat
# This file is normally only readable by root and the password will be deleted by the package management system after install.
echo mysql-server mysql-server/root_password password $mysqlPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $mysqlPassword | sudo debconf-set-selections
sudo apt-get install $aptget_arguments mysql-server mysql-client libmysqlclient-dev

#  =======================
#  = GitLab Installation =
#  =======================
#  
cd /home/git
# Clone GitLab repository
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab

# Go to gitlab dir
cd /home/git/gitlab

# Checkout to release
sudo -u git -H git checkout $gitlab_release

#  ========================
#  = GitLab Configuration =
#  ========================
#  
cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Replace localhost with domain
sudo -u git -H sed -i 's/localhost/$domain_var/g' config/gitlab.yml

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

# Copy the example Puma config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Configure Git global settings for git user
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@$domain_var"

#  =================================
#  = GitLab Database Configuration =
#  =================================

# Mysql
sudo -u git cp config/database.yml.mysql config/database.yml

# Insert database password into config
sed -i 's/"secure password"/$mysqlPassword/g' config/database.yml

# Replace MySQL user root with gitlab
# /**
 
#    TODO:
#    - Setup MySQL DB with gitlab user instead of root
 
#  **/
#sed -i 's/root/gitlab/g' config/database.yml

# Make config/database.yml readable to git only
sudo -u git -H chmod o-rwx config/database.yml

#  =======================
#  = GitLab Gems Install =
#  =======================
#  
cd /home/git/gitlab

sudo gem install charlock_holmes --version '0.6.9.4'

# For MySQL (note, the option says "without ... postgres")
sudo -u git -H bundle install --deployment --without development test postgres unicorn aws


#  ================================================
#  = Initialize DB and Activate Advanced Features =
#  ================================================
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

#  ======================
#  = GitLab Init Script =
#  ======================
#  
sudo cp lib/support/init.d/gitlab /etc/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab

# Set GitLab to start on boot
sudo update-rc.d gitlab defaults 21

#  ===================
#  = Apache Handling =
#  ===================
#  
if [ -f /etc/init.d/apache2 ]; then
  echo "=== Apache init found, attempting to stop"
  sudo /etc/init.d/apache2 stop
  echo "=== Disabling apache from starting at boot"
  sudo update-rc.d apache2 remove
fi

#  =================
#  = Install Nginx =
#  =================
echo "=== Attempting to install Nginx ..."
sudo apt-get install $aptget_arguments nginx
sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

# 5-3-stable and prior has YOUR_SERVER_IP in nginx conf, post 5-3-stable does not
sudo sed -i 's/YOUR_SERVER_IP:80/*:80/g' /etc/nginx/sites-available/gitlab

# Replace YOUR_SERVER_FQDN with domain
sudo sed -i "s/YOUR_SERVER_FQDN/$domain_var/g" /etc/nginx/sites-available/gitlab

#  ===========================
#  = Where the magic happens =
#  ===========================
sudo service gitlab start
sudo service nginx start

