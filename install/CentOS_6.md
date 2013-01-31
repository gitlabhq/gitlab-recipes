**This installation guide was created for CentOS 6.3 in combination with gitlab 4.0 and tested on it.**
We also tried this on RHEL 6.3 and found that there are subtle differences that we so far have only documeted in part.

Please read `doc/install/requirements.md` for hardware and platform requirements.

## Overview ##
This guide installs gitlab on a bare system from scratch using MySQL as the database. All Postgress installation steps are absent as they have not been tested yet.

**Important Note:**
The following steps have been known to work.
If you deviate from this guide, do it with caution and make sure you don't
violate any assumptions GitLab makes about its environment.
For things like AWS installation scripts, init scripts or config files for
alternative web server have a look at the "Advanced Setup Tips" section.

**Important Note:**
If you find a bug/error in this guide please submit an issue or pull request
following the contribution guide (see `CONTRIBUTING.md`).

**Note about accounts:**
In most cases you are required to run commands as the 'root' user.
When it is required you should be either the 'git' or 'gitlab' user it will be indicated with a line like this

*logged in as gitlab*

The best way to become that user is by logging in as root and typing

    su - gitlab

**Note about security:**
Many setup guides of Linux software simply state: "disable selinux and firewall".
The original gitlab installation for ubuntu disables StrictHostKeyChecking completely.
This guide does not disable any of them, we simply configure them as they were intended.

- - -

# Overview

The GitLab installation consists of setting up the following components:

1. Installing the base operating system (CentOS 6.3 Minimal) and Packages / Dependencies
2. Ruby
3. System Users
4. Gitolite
5. GitLab


----------

# 1. Installing the operating system (CentOS 6.3 Minimal)

We start with a completely clean CentOS 6.3 "minimal" installation which can be accomplished by downloading the appropriate installation iso file. Just boot the system of the iso file and install the system.

Note that during the installation you use the *"Configure Network"* option (it's a button in the same screen wher you speciify the hostname) to enable the *"Connect automatically"* option for the network interface and hand (usually eth0). 
**If you forget this option the network will NOT start at boot.**

The end result is a bare minimum CentOS installation that effectively only has network connectivity and no services at all.

## Updating and adding basic software and services
### Add EPEL repository

*logged in as root*

    rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

### Install the required tools for gitlab and gitolite

*logged in as root*

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

During an installation on an official RHEL 6.3 we found that some packages (in our case gdbm-devel, libffi-devel and libicu-devel) were NOT installed. You MUST make sure that all the packages are installed. The simplest way is to run the above command for a second time and you'll see quite easily of everything is either already installed or "No package XXX available". When you run into this issue you can try installing these required packages from the CentOS distribution.

### Update CentOS to the latest set of patches

*logged in as root*

    yum -y update

## Configure redis
Just make sure it is started at the next reboot

*logged in as root*

    chkconfig redis on
    service redis start

## Configure mysql
Make sure it is started at the next reboot and start it immediately so we can configure it.

*logged in as root*

    chkconfig mysqld on
    service mysqld start

Secure MySQL by entering a root password and say "Yes" to all questions with the next command

    /usr/bin/mysql_secure_installation

## Configure httpd

We use Apache HTTPD in front of gitlab
Just make sure it is started at the next reboot

    chkconfig httpd on

We want to be able to reach gitlab using the normal http ports (i.e. not the :3000 thing)
So we create a file called **/etc/httpd/conf.d/gitlab.conf** with this content (replace the git.example.org with your hostname!!). 

    <VirtualHost *:80>
      ServerName git.example.org
      ProxyRequests Off
        <Proxy *>
           Order deny,allow
           Allow from all
        </Proxy>
        ProxyPreserveHost On
        ProxyPass / http://localhost:3000/
        ProxyPassReverse / http://localhost:3000/
    </VirtualHost>

OPTIONAL: If you want to run other websites on the same system you'll need to enable in **/etc/httpd/conf/httpd.conf** the setting

    NameVirtualHost *:80

Poke an selinux hole for httpd so it can httpd can be in front of gitlab

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

*logged in as root*

    mkdir /tmp/ruby && cd /tmp/ruby
    wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p327.tar.gz
    tar xfvz ruby-1.9.3-p327.tar.gz
    cd ruby-1.9.3-p327
    ./configure
    make
    make install

Install the Bundler Gem:

*logged in as root*

    gem install bundler

----------

# 3. System Users

## Create users for Git and Gitolite
*logged in as root*

    adduser \
      --system \
      --shell /bin/bash \
      --comment 'Git Version Control' \
      --create-home \
      --home-dir /home/git \
      git

    adduser \
      --shell /bin/bash \
      --comment 'GitLab user' \
      --create-home \
      --home-dir /home/gitlab \
      gitlab

    usermod -a -G git gitlab 

Because the gitlab user will need a password later on, we configure it right now, so we are finished with all the user stuff.

    passwd gitlab # please choose a good password :)  

*logged in as root*

    # Generate the SSH key
    sudo -u gitlab -H ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

## Forwarding all emails

Now we want all logging of the system to be forwarded to a central email address

*logged in as root*

    echo adminlogs@example.com > /root/.forward
    chown root /root/.forward
    chmod 600 /root/.forward
    restorecon /root/.forward

    echo adminlogs@example.com > /home/gitlab/.forward
    chown gitlab /home/gitlab/.forward
    chmod 600 /home/gitlab/.forward
    restorecon /home/gitlab/.forward
    
----------

# 4. Gitolite

## Clone GitLab's fork of the Gitolite source code:

*logged in as root*

    cd /home/git
    sudo -u git -H git clone -b gl-v320 https://github.com/gitlabhq/gitolite.git /home/git/gitolite

## Setup Gitolite with GitLab as its admin:

**Important Note:**
GitLab assumes *full and unshared* control over this Gitolite installation.

*logged in as root*

    # Add Gitolite scripts to $PATH
    sudo -u git -H mkdir /home/git/bin
    sudo -u git -H sh -c 'printf "%b\n%b\n" "PATH=\$PATH:/home/git/bin" "export PATH" >> /home/git/.profile'
    sudo -u git -H sh -c 'gitolite/install -ln /home/git/bin'

    # Copy the gitlab user's (public) SSH key ...
    cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
    chmod 0444 /home/git/gitlab.pub

    # ... and use it as the admin key for the Gitolite setup
    sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gitolite setup -pk /home/git/gitlab.pub"

### Fix the directory permissions for the configuration directory:

    # Make sure the Gitolite config dir is owned by git
    chmod 750 /home/git/.gitolite/
    chown -R git:git /home/git/.gitolite/

### Fix the directory permissions for the repositories:

    # Make sure the repositories dir is owned by git and it stays that way
    chmod -R ug+rwXs,o-rwx /home/git/repositories/
    chown -R git:git /home/git/repositories/

    # Make sure the gitlab user can access the required directories
    chmod g+x /home/git

### Make the git account known and allowed to the gitlab user

*logged in as root*

    su - gitlab

*logged in as **gitlab***    
    
    ssh git@localhost  # type 'yes' and press <Enter>.

The expected behaviour is that you get a message similar to this and then immediately the connection is closed again:

    PTY allocation request failed on channel 0
    hello gitlab, this is git@gitlab running gitolite3 v3.2-gitlab-patched-0-g2d29cf7 on git 1.7.1

## Test if everything works so far
*logged in as **gitlab***

    # Clone the admin repo so SSH adds localhost to known_hosts ...
    # ... and to be sure your users have access to Gitolite
    git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin

    # If it succeeded without errors you can remove the cloned repo
    rm -rf /tmp/gitolite-admin

**Important Note:**
If you can't clone the `gitolite-admin` repository: **DO NOT PROCEED WITH INSTALLATION**!
Check the [Trouble Shooting Guide](https://github.com/gitlabhq/gitlab-public-wiki/wiki/Trouble-Shooting-Guide)
and make sure you have followed all of the above steps carefully.

----------
# 5. GitLab

*logged in as gitlab*

    # We'll install GitLab into home directory of the user "gitlab"
    cd /home/gitlab

## Clone the Source

    # Clone GitLab repository
    git clone https://github.com/gitlabhq/gitlabhq.git gitlab

    # Go to gitlab dir 
    cd /home/gitlab/gitlab
   
    # Checkout to stable release
    git checkout 4-0-stable

**Note:**
You can change `4-0-stable` to `master` if you want the *bleeding edge* version, but
do so with caution!

## Configure it

Copy the example GitLab config

    cp /home/gitlab/gitlab/config/gitlab.yml{.example,}

Edit the gitlab config to make sure to change "localhost" to the fully-qualified domain name of your host serving GitLab where necessary. Also review the other settings to match your setup.

    vim /home/gitlab/gitlab/config/gitlab.yml

Copy the example Unicorn config
    cp /home/gitlab/gitlab/config/unicorn.rb{.example,}

Edit the unicorn config

    vim /home/gitlab/gitlab/config/unicorn.rb

Change the listen parameter so that it reads:

    listen "127.0.0.1:3000"  # listen to port 3000 on the loopback interface

Also review the other settings to match your setup.

## Configure GitLab DB settings

    # MySQL
    cp /home/gitlab/gitlab/config/database.yml{.mysql,}

Edit the database config and set the correct username/password

    vim /home/gitlab/gitlab/config/database.yml

The config should look something like this (where supersecret is replaced with your real password):

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
*logged in as **gitlab***

    logout

*logged in as **root***

    cd /home/gitlab/gitlab

    gem install charlock_holmes --version '0.6.9'

    su - gitlab

*logged in as **gitlab***

    cd /home/gitlab/gitlab

    # For mysql db
    bundle install --deployment --without development test postgres

## Configure Git

GitLab needs to be able to commit and push changes to Gitolite. In order to do
that Git requires a username and email. (We recommend using the same address
used for the `email.from` setting in `config/gitlab.yml`)

*logged in as gitlab*

    git config --global user.name "GitLab"
    git config --global user.email "gitlab@localhost"

## Setup GitLab Hooks
*logged in as **gitlab***

    logout

*logged in as **root***

    cd /home/gitlab/gitlab
    cp ./lib/hooks/post-receive /home/git/.gitolite/hooks/common/post-receive
    chown git:git /home/git/.gitolite/hooks/common/post-receive

## Initialise Database and Activate Advanced Features

*logged in as **root***

    su - gitlab

*logged in as **gitlab***

    cd /home/gitlab/gitlab
    bundle exec rake gitlab:app:setup RAILS_ENV=production

The previous command will ask you for the root password of the mysql database and create the defined database and user.

## Install Init Script

Download the init script (will be /etc/init.d/gitlab)

*logged in as **gitlab***

    logout

*logged in as root*

    curl https://raw.github.com/gitlabhq/gitlab-recipes/master/init.d/gitlab-centos > /etc/init.d/gitlab
    chmod +x /etc/init.d/gitlab
    chkconfig --add gitlab

Make GitLab start on boot:

    chkconfig gitlab on

Start your GitLab instance:

    service gitlab start
    # or
    /etc/init.d/gitlab start

## Check Application Status

Check if GitLab and its environment is configured correctly:

    su - gitlab

*logged in as **gitlab***

    cd /home/gitlab/gitlab
    bundle exec rake gitlab:env:info RAILS_ENV=production

To make sure you didn't miss anything run a more thorough check with:

    cd /home/gitlab/gitlab
    bundle exec rake gitlab:check RAILS_ENV=production

If you are all green: congratulations, you successfully installed GitLab!
Although this is the case, there are still a few steps to go.

# Done!

Visit YOUR_SERVER for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    admin@local.host
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately change the password, so
nobody can access your GitLab by using this login information later on.

**Enjoy!**


- - -


# Advanced Setup Tips

## Custom Redis Connection

If you'd like Resque to connect to a Redis server on a non-standard port or on
a different host, you can configure its connection string via the
`config/resque.yml` file.

    # example
    production: redis.example.tld:6379


## User-contributed Configurations

You can find things like  AWS installation scripts, init scripts or config files
for alternative web server in our [recipes collection](https://github.com/gitlabhq/gitlab-recipes/).

