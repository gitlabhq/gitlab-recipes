```
Distribution      : CentOS 6.4
GitLab version    : 6.0
Web Server        : Apache, Nginx
Init system       : sysvinit
Database          : mysql
Contributors      : @nielsbasjes, @axilleas, @mairin, @ponsjuh, @yorn
Additional Notes  : In order to get the latest git version we build it from source
```

## Overview

Please read `doc/install/requirements.md` for hardware and platform requirements.

This guide installs GitLab on a bare system from scratch, using MySQL as the database.
All Postgres installation steps are absent as they have not been tested yet.
Pull requests with tested Postgres are welcome!

### Important Notes

The following steps have been known to work and should be followed from up to bottom.
If you deviate from this guide, do it with caution and make sure you don't violate
any assumptions GitLab makes about its environment. We have also tried this on
RHEL 6.3 and found that there are subtle differences which are documented in part.
Look for the **RHEL Notes** note.

#### If you find a bug

If you find a bug/error in this guide please submit an issue or pull request
following the contribution guide (see [CONTRIBUTING.md](../../CONTRIBUTING.md)).

#### Security

Many setup guides of Linux software simply state: "disable selinux and firewall".
This guide does not disable any of them, we simply configure them as they were intended.

- - -

The GitLab installation consists of setting up the following components:

1. Install the base operating system (CentOS 6.4 Minimal) and Packages / Dependencies
2. Ruby
3. System Users
4. GitLab shell
5. Database
6. GitLab
7. Web server
8. Firewall

----------

## 1. Installing the operating system (CentOS 6.4 Minimal)

We start with a completely clean CentOS 6.4 "minimal" installation which can be
accomplished by downloading the appropriate installation iso file. Just boot the
system of the iso file and install the system.

Note that during the installation you use the *"Configure Network"* option (it's a
button in the same screen where you specify the hostname) to enable the *"Connect automatically"*
option for the network interface and hand (usually eth0).

**If you forget this option the network will NOT start at boot.**

The end result is a bare minimum CentOS installation that effectively only has
network connectivity and (almost) no services at all.

## Updating and adding basic software and services

### Add EPEL repository

[EPEL][] is a volunteer-based community effort from the Fedora project to create
a repository of high-quality add-on packages that complement the Fedora-based
Red Hat Enterprise Linux (RHEL) and its compatible spinoffs, such as CentOS and Scientific Linux.

As part of the Fedora packaging community, EPEL packages are 100% free/libre open source software (FLOSS).

Download the GPG key for EPEL repository from [fedoraproject][keys] and install it on your system:

    sudo wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6 https://fedoraproject.org/static/0608B895.txt
    sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

Verify that the key got installed successfully:

    sudo rpm -qa gpg*
    gpg-pubkey-0608b895-4bd22942

Now install the `epel-release-6-8.noarch` package, which will enable EPEL repository on your system:

    sudo rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

**Note:** Don't mind the `x86_64`, if you install on a i686 system you can use the same commands.

Verify that the EPEL repository is enabled as shown below. Now, you’ll see epel
repository (apart from the standard base, updates and extras repositories):

    sudo yum repolist
    repo id             repo name                                                status
    base                CentOS-6 - Base                                          4,802
    epel                Extra Packages for Enterprise Linux 6 - x86_64           7,879
    extras              CentOS-6 - Extras                                           12
    updates             CentOS-6 - Updates                                         814
    repolist: 13,507

If you can't see it listed, use the folowing command to enable it:

    sudo yum-config-manager --enable epel

### Install the required tools for GitLab

    su -
    yum -y update
    yum -y groupinstall 'Development Tools'

    ### 'Additional Development'
    yum -y install vim-enhanced readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui python-devel redis sudo wget crontabs logwatch logrotate perl-Time-HiRes

**RHEL Notes**

If some packages (eg. gdbm-devel, libffi-devel and libicu-devel) are NOT installed,
add the rhel6 optional packages repo to your server to get those packages:

    yum-config-manager --enable rhel-6-server-optional-rpms

Tip taken from [here](https://github.com/gitlabhq/gitlab-recipes/issues/62).

### Git

GitLab will only work correctly with git version 1.8.x or newer. The problem is
that the available rpms for CentOS stop at git 1.7.1 which is too old for GitLab.
In order to update, you have to build git from source as it is not yet in any repository:

    su -
    cd /tmp
    yum -y install git perl-ExtUtils-MakeMaker
    git clone git://github.com/git/git.git
    cd /tmp/git/
    git checkout v1.8.3.4
    autoconf
    ./configure --prefix=/usr/local
    make && make install
    rm -rf /tmp/git/
    yum erase git

Logout and login again for the `$PATH` to take effect. Check that git is properly
installed with:

    which git
    # /usr/local/bin/git
    git --version
    # git version 1.8.3.4

### Configure redis
Make sure redis is started on boot:


    sudo chkconfig redis on
    sudo service redis start

### Configure sendmail

    su -
    yum -y install sendmail-cf
    cd /etc/mail
    vim /etc/mail/sendmail.mc

Add a line with the smtp gateway hostname

    define(`SMART_HOST', `smtp.example.com')dnl

Then replace this line:

    EXPOSED_USER(`root')dnl

with:

    dnl EXPOSED_USER(`root')dnl

Now enable these settings:

    make
    chkconfig sendmail on

Alternatively you can install `postfix`.

----------

## 2. Ruby
Download and compile it:

    su -
    mkdir /tmp/ruby && cd /tmp/ruby
    curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
    cd ruby-2.0.0-p247
    ./configure --prefix=/usr/local/
    make && make install

Logout and login again for the `$PATH` to take effect. Check that ruby is properly
installed with:

    which ruby
    # /usr/local/bin/ruby
    ruby -v
    # ruby 2.0.0p247 (2013-06-27 revision 41674) [x86_64-linux]

Install the Bundler Gem:

     sudo gem install bundler --no-ri --no-rdoc

**NOTE:** If you get an error like `sudo: gem: command not found`, it is because
CentOS has sudo built with the `--with-secure-path` flag. See this post on [stackoverflow][sudo]
on how to deal with it. Alternatively, login as root and run the command.

----------

## 3. System Users

### Create user for Git

    su -
    adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git

We do NOT set the password so this user cannot login.

### Forwarding all emails

Now we want all logging of the system to be forwarded to a central email address:

    su -
    echo adminlogs@example.com > /root/.forward
    chown root /root/.forward
    chmod 600 /root/.forward
    restorecon /root/.forward

    echo adminlogs@example.com > /home/git/.forward
    chown git /home/git/.forward
    chmod 600 /home/git/.forward
    restorecon /home/git/.forward

----------

## 4. GitLab shell

GitLab Shell is a ssh access and repository management software developed specially for GitLab.

```
# First login as root
su -

# Login as git
su - git

# Clone gitlab shell
git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell

# Switch to right version
git checkout v1.7.0
cp config.yml.example config.yml

# Edit config and replace gitlab_url with something like 'http://domain.com/'

# Do setup
./bin/install
```
----------

## 5. Database

Install `mysql` and enable the `mysqld` service to start on boot:

    su -
    yum install -y mysql-server mysql-devel
    chkconfig mysqld on
    service mysqld start

Secure MySQL by entering a root password and say "Yes" to all questions:

    /usr/bin/mysql_secure_installation

Create a new user and database for GitLab:

    # Login to MySQL
    mysql -u root -p
    # Type the database root password
    # Create a user for GitLab. (change supersecret to a real password)
    CREATE USER 'gitlab'@'localhost' IDENTIFIED BY 'supersecret';

    # Create the GitLab production database
    CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;

    # Grant the GitLab user necessary permissopns on the table.
    GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'gitlab'@'localhost';

    # Quit the database session
    \q

Try connecting to the new database with the new user:

    mysql -u gitlab -p -D gitlabhq_production
    # Type the password you replaced supersecret with earlier
    # Quit the database session
    \q

----------
## 6. GitLab

We'll install GitLab into home directory of the user `git`:

    su -
    su - git

### Clone the Source

    # Clone GitLab repository
    git clone https://github.com/gitlabhq/gitlabhq.git gitlab

    # Go to gitlab directory
    cd /home/git/gitlab

    # Checkout to stable release
    git checkout 6-0-stable

**Note:** You can change `6-0-stable` to `master` if you want the *bleeding edge* version, but
do so with caution!

### Configure it

```
# Copy the example GitLab config
cp config/gitlab.yml.example config/gitlab.yml

# Replace your_domain_name with the fully-qualified domain name of your host serving GitLab
sed -i 's|localhost|your_domain_name|g' config/gitlab.yml

# Change git's path to point to /usr/local/bin/git
sed -i 's|/usr/bin/git|/usr/local/bin/git|' config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
chown -R git log/
chown -R git tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

# Create directory for satellites
mkdir /home/git/gitlab-satellites

# Create directories for sockets/pids and make sure GitLab can write to them
mkdir tmp/pids/
mkdir tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

# Create public/uploads directory otherwise backup will fail
mkdir public/uploads
chmod -R u+rwX  public/uploads

# Copy the example Unicorn config
cp config/unicorn.rb.example config/unicorn.rb

# Enable cluster mode if you expect to have a high load instance
# E.g. change amount of workers to 3 for 2GB RAM server
editor config/unicorn.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
git config --global user.name "GitLab"
git config --global user.email "gitlab@your_domain_name"
git config --global core.autocrlf input
```

**Important:** Make sure to edit both `gitlab.yml` and `unicorn.rb` to match your setup.

### Configure GitLab DB settings

    # MySQL
    cp config/database.yml{.mysql,}

Make sure to update username/password in `config/database.yml`. You only need to adapt the production settings (first part).

If you followed the database guide then please do as follows:
* Change `root` to `gitlab`.
* Change `secure password` with the value you have given to supersecret.

You can keep the double quotes around the password.

    editor config/database.yml

Make config/database.yml readable to git only

    chmod o-rwx config/database.yml

### Install Gems

    su -
    gem install charlock_holmes --version '0.6.9.4'
    exit

For MySQL (note, the option says "without ... postgres"):

    cd /home/git/gitlab/
    bundle install --deployment --without development test postgres puma aws


### Initialize Database and Activate Advanced Features

    cd /home/git/gitlab
    bundle exec rake gitlab:setup RAILS_ENV=production

Type 'yes' to create the database.
When done you see 'Administrator account created:'

### Install Init Script

Download the init script (will be /etc/init.d/gitlab):

    su -
    wget -O /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/init/sysvinit/centos/gitlab-unicorn
    chmod +x /etc/init.d/gitlab
    chkconfig --add gitlab

Make GitLab start on boot:

    chkconfig gitlab on

### Check Application Status

Check if GitLab and its environment are configured correctly:

    su - git
    cd gitlab/
    bundle exec rake gitlab:env:info RAILS_ENV=production
    exit

### Start your GitLab instance:

    service gitlab start

### Double-check Application Status

To make sure you didn't miss anything run a more thorough check with:

    su - git
    cd gitlab/
    bundle exec rake gitlab:check RAILS_ENV=production

If all items are green, then congratulations on successfully installing GitLab!
However there are still a few steps left.

## 7. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx.

### Nginx

```
su -
yum -y install nginx
chkconfig nginx on
mkdir /etc/nginx/sites-{available,enabled}
wget -O /etc/nginx/sites-available/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/web-server/nginx/gitlab-ssl
ln -sf /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
```

Edit `/etc/nginx/nginx.conf` and replace `include /etc/nginx/conf.d/*.conf;`
with `/etc/nginx/sites-enabled/*;`

Add `nginx` user to `git` group.

    usermod -a -G git nginx
    chmod g+rx /home/git/

Finally start nginx with:

    service nginx start

**Note:** Don't forget to add a SSL certificate or generate a Self Signed Certificate

    cd /etc/nginx
    openssl req -new -x509 -nodes -days 3560 -out gitlab.crt -keyout gitlab.key

### Apache

We will configure apache with module `mod_proxy` which is loaded by default when
installing apache:

```
su -
yum -y install httpd mod_ssl
chkconfig httpd on
wget -O /etc/httpd/conf.d/gitlab.conf https://raw.github.com/gitlabhq/gitlab-recipes/master/web-server/apache/gitlab.conf
```

Open `/etc/httpd/conf.d/gitlab.conf` with your editor and replace `git.example.org` with your FQDN.

Add `LoadModule ssl_module /etc/httpd/modules/mod_ssl.so` in `/etc/httpd/conf/httpd.conf`

If you want to run other websites on the same system, you'll need to add in `/etc/httpd/conf/httpd.conf`:

```
NameVirtualHost *:80
<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/httpd/conf.d/gitlab.conf
    # to <VirtualHost *:443>
    NameVirtualHost *:443
    Listen 443
</IfModule>
```

Poke a selinux hole for httpd so it can be in front of GitLab:

    setsebool -P httpd_can_network_connect on

Start apache:

    service httpd start

## 8. Configure the firewall

Poke an iptables hole so users can access the httpd (http and https ports) and ssh.

    lokkit -s http -s https -s ssh

Restart the service for the changes to take effect:

    service iptables restart

## Done!

Visit YOUR_SERVER for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    admin@local.host
    5iveL!fe

You will then be redirected to change the default admin password.

## Links used in this guide

- [EPEL information](http://www.thegeekstuff.com/2012/06/enable-epel-repository/)
- [git update to 1.8.x](http://www.pickysysadmin.ca/2013/05/21/commit-comments-not-appearing-in-gitlab-on-centos/)
- [SELinux booleans](http://wiki.centos.org/TipsAndTricks/SelinuxBooleans)


[EPEL]: https://fedoraproject.org/wiki/EPEL
[keys]: https://fedoraproject.org/keys
[sudo]: http://stackoverflow.com/questions/257616/sudo-changes-path-why
