#!/bin/sh

# GITLAB
# Maintainer: @dosire
# App Version: 2.9

# ABOUT
# This script performs a complete installation of Gitlab (master branch).
# Is can be run with one command without needing _any_ user input after that.
# This script only works on Amazon Web Services (AWS).
# The operating system used is Ubuntu 12.04 64bit.

# HOWTO
# Signup for AWS, a free usage tier is available at http://aws.amazon.com/free/
# Go to EC2 tab in the AWS console EC2 https://console.aws.amazon.com/ec2/home
# Click the 'Launch Instance' button
# Select: 'Quick launch wizard' and continue
# Under "Choose a key pair" select "Create New"
# Write a name for the key in "Name" field and Download it. Place it in a known location since it will be used in one of the next steps.
# Under "Choose a Launch Configuration", select 'More Amazon Machine Images'.
# Press 'Continue'
# Enter 'ubuntu/images/ubuntu-precise-12.04-amd64-server-20120424' in the search field and press 'Search'
# Select the only result (ami-3c994355) and press 'Continue'
# Press 'Edit details' if you want to modify something, for example make the type 'c1.medium' to make the install faster.
# Press the 'Launch' button
# Press 'Close'
# Click 'Security Groups' under the left hand menu 'NETWORK & SECURITY' in aws console.
# Select the newly create security group, probably named 'quicklaunch-1'
# Click on the Inbound tab
# In the 'Create a new rule' dropdown select 'HTTP', leave the default value in the "Source" field.
# Press 'Add Rule'
# In the 'Create a new rule' dropdown select 'HTTPS', leave the default value in the "Source" field.
# Press 'Add Rule'
# Press 'Apply Rule Changes'
# In Navigation side panel, under Instances -> Instances you can see when the instance is ready.
# Give the following command in your local terminal while substituting the UPPERCASE items( ommit the '')
# 'ssh -i LOCATION_OF_AWS_KEY_PAIR_PRIVATE_KEY ubuntu@PUBLIC_DNS_OF_THE_NEW_SERVER'
# where LOCATION_OF_AWS_KEY_PAIR_PRIVATE_KEY is the location of the key saved on your local machine. Permissions of the .pem file have to be at least 600 (chmod 600 NAME_OF_PRIVATE_KEY.pem).
# PUBLIC_DNS_OF_THE_NEW_SERVER can be viewed by selecting the aws instance created in previous steps and selecting the 'Description' tab
# Execute the curl command below and when its ready follow the printed 'Log in instuctions'
# curl https://raw.github.com/gitlabhq/gitlab-recipes/master/install/debian_ubuntu_aws.sh | sh

# Prevent fingerprint prompt for localhost in step 1 to 3.
echo "Host localhost
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null" | sudo tee -a /etc/ssh/ssh_config

sudo DEBIAN_FRONTEND='noninteractive' apt-get install -y postfix-policyd-spf-python postfix # Install postfix without prompting.

# Existing script for Step 1 to 3
curl https://raw.github.com/gitlabhq/gitlab-recipes/master/install/debian_ubuntu.sh >> debian_ubuntu.sh
sed -i 's/postfix//' debian_ubuntu.sh # This will prompt even when postfix is already installed.
sed -i '/sudo\ apt-get\ upgrade/d' debian_ubuntu.sh # Upgrade can cause prompting for various packages (grub, etc.).
sh debian_ubuntu.sh

# Install MySQL
sudo apt-get install -y makepasswd # Needed to create a unique password non-interactively.
userPassword=$(makepasswd --char=10) # Generate a random MySQL password
# Note that the lines below creates a cleartext copy of the random password in /var/cache/debconf/passwords.dat
# This file is normally only readable by root and the password will be deleted by the package management system after install.
echo mysql-server mysql-server/root_password password $userPassword | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $userPassword | sudo debconf-set-selections
sudo apt-get install -y mysql-server libpq-dev

# Gitlab install
sudo gem install charlock_holmes --version '0.6.8'
sudo pip install pygments
sudo gem install bundler
sudo su -l gitlab -c "git clone git://github.com/gitlabhq/gitlabhq.git gitlab" # Using master everywhere.
sudo su -l gitlab -c "cd gitlab && mkdir tmp"
sudo su -l gitlab -c "cd gitlab/config && cp gitlab.yml.example gitlab.yml"
sudo su -l gitlab -c "cd gitlab/config && cp database.yml.example database.yml"
sudo sed -i 's/"secure password"/"'$userPassword'"/' /home/gitlab/gitlab/config/database.yml # Insert the mysql root password.
sudo su -l gitlab -c "cd gitlab && bundle install --without development test --deployment"
sudo su -l gitlab -c "cd gitlab && bundle exec rake gitlab:app:setup RAILS_ENV=production"

# Setup gitlab hooks
sudo cp /home/gitlab/gitlab/lib/hooks/post-receive /home/git/.gitolite/hooks/common/post-receive
sudo chown git:git /home/git/.gitolite/hooks/common/post-receive
sudo chmod g+rwx /home/git/.gitolite # sort out permissions https://github.com/gitlabhq/gitlabhq/issues/1543
sudo usermod -g git gitlab


# Set the first occurrence of host in the Gitlab config to the publicly available domain name
sudo sed -i '0,/host/s/localhost/'`wget -qO- http://instance-data/latest/meta-data/public-hostname`'/' /home/gitlab/gitlab/config/gitlab.yml

# Tighten security
sudo -u git chmod 750 /home/git/gitolite
sudo -u gitlab chmod 660 /home/gitlab/gitlab/config/*.yml

# Install and configure Nginx
sudo apt-get install -y nginx
sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/master/nginx/gitlab -P /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sudo sed -i 's/YOUR_SERVER_IP/'`wget -qO- http://instance-data/latest/meta-data/local-ipv4`'/' /etc/nginx/sites-available/gitlab # Set private ip address (public won't work).
sudo sed -i 's/YOUR_SERVER_FQDN/'`wget -qO- http://instance-data/latest/meta-data/public-hostname`'/' /etc/nginx/sites-available/gitlab # Set public dns domain name.

# Configure Unicorn
sudo -u gitlab cp /home/gitlab/gitlab/config/unicorn.rb.example /home/gitlab/gitlab/config/unicorn.rb

# Create a Gitlab service
sudo wget https://raw.github.com/gitlabhq/gitlab-recipes/master/init.d/gitlab -P /etc/init.d/
sudo chmod +x /etc/init.d/gitlab && sudo update-rc.d gitlab defaults

## Gitlab service commands (unicorn and resque)
## restart doesn't restart resque, only start/stop effect it.
sudo -u gitlab service gitlab start

# nginx Service commands
sudo service nginx restart

# Go to gitlab directory by default on next login.
echo 'cd /home/gitlab/gitlab' >> /home/ubuntu/.bashrc

echo ''
echo '###########################################'
echo '#          Log in instuctions             #'
echo '###########################################'
echo ''
echo "Surf to this Gitlab installation in your browser:"
echo "http://`wget -qO- http://instance-data/latest/meta-data/public-hostname`/"
echo ''
echo 'and login with the following Email and Password:'
echo 'admin@local.host'
echo '5iveL!fe'

# If you need it the database password can be found in '/home/gitlab/gitlab/config/database.yml'.

# Gitlab installation test:
# sudo -u gitlab bundle exec rake gitlab:app:status RAILS_ENV=production

# Stating and stopping services:
# To stop gitlab use: 'sudo -u gitlab service gitlab stop'
# To stop nginx server use: 'sudo service nginx stop'
# Replace stop with start to start those services.

# Manual startup commands for troubleshooting when the service commands do not work:
# sudo -u gitlab bundle exec unicorn_rails -c config/unicorn.rb -E production -D
# sudo su -l gitlab -c "cd gitlab && ./resque.sh"
# sudo -u gitlab bundle exec rails s -e production
# sudo -u gitlab bundle exec rake environment resque:work QUEUE=* RAILS_ENV=production BACKGROUND=no

# Monitoring commands for the web server:
# sudo tail -f /var/log/nginx/gitlab_access.log
# sudo tail -f /var/log/nginx/gitlab_error.log
