# GITLAB
# Maintainer: @nielsbasjes
# App Version: 5.2

**This installation guide was created for CentOS 6.4 in combination with gitlab 5.2 and tested on it.**
We also tried this on RHEL 6.3 and found that there are subtle differences that we so far have only documented in part.

Please read `doc/install/requirements.md` for hardware and platform requirements.

## Overview ##
This guide installs gitlab on a bare system from scratch using MySQL as the database. All Postgress installation steps are absent as they have not been tested yet.

**Important Note:**
The following steps have been known to work.
If you deviate from this guide, do it with caution and make sure you don't
violate any assumptions GitLab makes about its environment.

**Important Note:**
If you find a bug/error in this guide please submit an issue or pull request
following the contribution guide (see `CONTRIBUTING.md`).

**Note about accounts:**
In most cases you are required to run commands as the 'root' user.
When it is required you should be either the 'git' or 'root' user it will be indicated with a line like this

*logged in as **git***

The best way to become that user is by logging in as root and typing

    su - git

**Note about security:**
Many setup guides of Linux software simply state: "disable selinux and firewall".
The original gitlab installation for ubuntu disables StrictHostKeyChecking completely.
This guide does not disable any of them, we simply configure them as they were intended.

- - -

# Overview

The GitLab installation consists of setting up the following components:

1. Installing the base operating system (CentOS 6.4 Minimal) and Packages / Dependencies
2. Ruby
3. System Users
4. GitLab shell
5. GitLab


----------

# 1. Installing the operating system (CentOS 6.4 Minimal)

We start with a completely clean CentOS 6.4 "minimal" installation which can be accomplished by downloading the appropriate installation iso file. Just boot the system of the iso file and install the system.

Note that during the installation you use the *"Configure Network"* option (it's a button in the same screen where you specify the hostname) to enable the *"Connect automatically"* option for the network interface and hand (usually eth0). 
**If you forget this option the network will NOT start at boot.**

The end result is a bare minimum CentOS installation that effectively only has network connectivity and (almost) no services at all.

## Updating and adding basic software and services
### Add EPEL repository

*logged in as **root***

    rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

### Install the required tools for gitlab

*logged in as **root***

    yum -y groupinstall 'Development Tools'

    ### 'Additional Development'
    yum -y install vim-enhanced httpd readline readline-devel ncurses-devel gdbm-devel glibc-devel \
                   tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc \
                   sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel \
                   libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel \
                   system-config-firewall-tui python-devel redis sudo mysql-server wget \
                   mysql-devel crontabs logwatch logrotate sendmail-cf qtwebkit qtwebkit-devel \
                   perl-Time-HiRes

**IMPORTANT NOTE About Redhat EL 6** 

During an installation on an official RHEL 6.3 we found that some packages (in our case gdbm-devel, libffi-devel and libicu-devel) were NOT installed. You MUST make sure that all the packages are installed. Someone told me that you can get these "packages direct from RHEL by enabling the “RHEL Server Optional” Channel in RHN.". I haven't tried this yet.

### Update CentOS to the latest set of patches

*logged in as **root***

    yum -y update

## Git
For some reason gitlab has been written in such a way that it will only work correctly with git version 1.8.x or newer. At the time of writing [this commit](https://github.com/gitlabhq/gitlabhq/commit/b1a8fdd84d5a7cdbdb5ef3829b59a73db0f4d2dd) was the culprit that enforced this requirement.
In case this has not been resolved when you read this you must either update your git to > 1.8.x or revert the above mentioned change manually.

Have a look at [this HowTo](http://www.pickysysadmin.ca/2013/05/21/commit-comments-not-appearing-in-gitlab-on-centos/) on one possible way of updating the git version.

## Configure redis
Just make sure it is started at the next reboot

*logged in as **root***

    chkconfig redis on

## Configure mysql
Make sure it is started at the next reboot and start it immediately so we can configure it.

*logged in as **root***

    chkconfig mysqld on
    service mysqld start

Secure MySQL by entering a root password and say "Yes" to all questions with the next command

    /usr/bin/mysql_secure_installation

## Configure httpd

We use Apache HTTPD in front of gitlab
Just make sure it is started at the next reboot

    chkconfig httpd on

We want to be able to reach gitlab using the normal http ports (i.e. not the :9292 thing)
So we create a file called **/etc/httpd/conf.d/gitlab.conf** with this content (replace the git.example.org with your hostname!!). 

    <VirtualHost *:80>
      ServerName git.example.org
      ProxyRequests Off
        <Proxy *>
           Order deny,allow
           Allow from all
        </Proxy>
        ProxyPreserveHost On
        ProxyPass / http://localhost:9292/
        ProxyPassReverse / http://localhost:9292/
    </VirtualHost>

OPTIONAL: If you want to run other websites on the same system you'll need to enable in **/etc/httpd/conf/httpd.conf** the setting

    NameVirtualHost *:80

Poke a selinux hole for httpd so it can httpd can be in front of gitlab

    setsebool -P httpd_can_network_connect on

## Configure firewall

Poke an iptables hole so uses can access the httpd (http and https ports) and ssh.
The quick way is to put this in the file called **/etc/sysconfig/iptables**

    # Firewall configuration written by system-config-firewall
    # Manual customization of this file is not recommended.
    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [0:0]
    -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A INPUT -p icmp -j ACCEPT
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
    -A INPUT -j REJECT --reject-with icmp-host-prohibited
    -A FORWARD -j REJECT --reject-with icmp-host-prohibited
    COMMIT

## Configure email

    cd /etc/mail
    vim /etc/mail/sendmail.mc

Add a line with the smtp gateway hostname

    define(`SMART_HOST', `smtp.example.com')dnl

Then comment out this line 

    EXPOSED_USER(`root')dnl

by putting 'dnl ' in front of it like this

    dnl EXPOSED_USER(`root')dnl
 
Now enable these settings

    make
    chkconfig sendmail on


## Reboot
Now that we have the basics right we reboot the system to load the new kernel and everything.
After the reboot all of the so far installed services will startup automatically.

    reboot

----------

# 2. Ruby
Download and compile it:

*logged in as **root***

    mkdir /tmp/ruby && cd /tmp/ruby
    wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p392.tar.gz
    tar xfvz ruby-1.9.3-p392.tar.gz
    cd ruby-1.9.3-p392
    ./configure
    make
    make install

Install the Bundler Gem:

*logged in as **root***

    gem install bundler

----------

# 3. System Users

## Create user for Git
*logged in as **root***

    adduser \
      --system \
      --shell /bin/bash \
      --comment 'Git Version Control' \
      --create-home \
      --home-dir /home/git \
      git

We do NOT set the password so this user cannot login.

## Forwarding all emails

Now we want all logging of the system to be forwarded to a central email address

*logged in as **root***

    echo adminlogs@example.com > /root/.forward
    chown root /root/.forward
    chmod 600 /root/.forward
    restorecon /root/.forward

    echo adminlogs@example.com > /home/git/.forward
    chown git /home/git/.forward
    chmod 600 /home/git/.forward
    restorecon /home/git/.forward

## Database user


*logged in as **root***

    su - git

*logged in as **git***

    # Login to MySQL
    mysql -u root -p

    # Create a user for GitLab. (change supersecret to a real password)
    CREATE USER 'gitlab'@'localhost' IDENTIFIED BY 'supersecret';

    # Create the GitLab production database
    CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;

    # Grant the GitLab user necessary permissopns on the table.
    GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'gitlab'@'localhost';

    # Quit the database session
    \q

Try connecting to the new database with the new user

    mysql -u gitlab -p -D gitlabhq_production

----------

# 4. GitLab shell

GitLab Shell is a ssh access and repository management software developed specially for GitLab.

    # Login as git
    su - git

*logged in as **git***

    # Go to home directory
    cd /home/git

    # Clone gitlab shell
    git clone https://github.com/gitlabhq/gitlab-shell.git
    cd gitlab-shell

    # switch to right version
    git checkout v1.4.0

    cp config.yml.example config.yml

    # Edit config and replace gitlab_url
    # with something like 'http://domain.com/'
    vim config.yml

    # Do setup
    ./bin/install


----------
# 5. GitLab

*logged in as **git***

    # We'll install GitLab into home directory of the user "git"
    cd /home/git

## Clone the Source

    # Clone GitLab repository
    git clone https://github.com/gitlabhq/gitlabhq.git gitlab

    # Go to gitlab dir 
    cd /home/git/gitlab
   
    # Checkout to stable release
    git checkout 5-2-stable

**Note:**
You can change `5-2-stable` to `master` if you want the *bleeding edge* version, but
do so with caution!

## Configure it

Copy the example GitLab config

    cp /home/git/gitlab/config/gitlab.yml{.example,}

Edit the gitlab config to make sure to change "localhost" to the fully-qualified domain name of your host serving GitLab where necessary. Also review the other settings to match your setup.

    vim /home/git/gitlab/config/gitlab.yml

*logged in as **root***

    # Make sure GitLab can write to the log/ and tmp/ directories
    chown -R git    /home/git/gitlab/log/
    chown -R git    /home/git/gitlab/tmp/
    chmod -R u+rwX  /home/git/gitlab/log/
    chmod -R u+rwX  /home/git/gitlab/tmp/

*logged in as **git***

    # Create directory for satellites
    mkdir /home/git/gitlab-satellites

    # Create directories for sockets/pids and make sure GitLab can write to them
    mkdir /home/git/gitlab/tmp/pids/
    mkdir /home/git/gitlab/tmp/sockets/
    chmod -R u+rwX /home/git/gitlab/tmp/pids/
    chmod -R u+rwX /home/git/gitlab/tmp/sockets/

    # Create public/uploads directory otherwise backup will fail
    mkdir /home/git/gitlab/public/uploads
    chmod -R u+rwX /home/git/gitlab/public/uploads

    # Copy the example Puma config
    cp /home/git/gitlab/config/puma.rb{.example,}

    # Configure Git global settings for git user, useful when editing via web
    # Edit user.email according to what is set in gitlab.yml
    git config --global user.name "GitLab"
    git config --global user.email "gitlab@localhost"


**Important Note:**
Make sure to edit both `gitlab.yml` and `puma.rb` to match your setup.

Specifically for our setup behind Apache edit the puma config

    vim /home/git/gitlab/config/puma.rb

Change the bind parameter so that it reads:

    bind 'tcp://127.0.0.1:9292'

## Configure GitLab DB settings

    # MySQL
    cp /home/git/gitlab/config/database.yml{.mysql,}

Edit the database config and set the correct username/password

    vim /home/git/gitlab/config/database.yml

The config should look something like this (where *supersecret* is replaced with your real password):

    production:
      adapter: mysql2
      encoding: utf8
      reconnect: false
      database: gitlabhq_production
      pool: 5
      username: gitlab
      password: supersecret
      # host: localhost
      # socket: /tmp/mysql.sock
    
## Install Gems
*logged in as **git***

    logout

*logged in as **root***

    cd /home/git/gitlab

    gem install charlock_holmes --version '0.6.9.4'

    su - git

*logged in as **git***

    cd /home/git/gitlab

    # For mysql db
    bundle install --deployment --without development test postgres


## Initialize Database and Activate Advanced Features

*logged in as **git***

    cd /home/git/gitlab
    bundle exec rake gitlab:setup RAILS_ENV=production

## Install Init Script

Download the init script (will be /etc/init.d/gitlab)

*logged in as **git***

    logout

*logged in as **root***

**Double check the url for this next one!!**

    curl https://raw.github.com/gitlabhq/gitlab-recipes/master/init/sysvinit/centos/gitlab-centos > /etc/init.d/gitlab
    chmod +x /etc/init.d/gitlab
    chkconfig --add gitlab

Make GitLab start on boot:

    chkconfig gitlab on

Start your GitLab instance:

    service gitlab start
    # or
    /etc/init.d/gitlab start


# Done!

Visit YOUR_SERVER for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    admin@local.host
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately change the password, so
nobody can access your GitLab by using this login information later on.

**Enjoy!**
