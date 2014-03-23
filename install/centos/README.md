```
Distribution      : CentOS 6.5
GitLab version    : 6.0 - 6.6
Web Server        : Apache, Nginx
Init system       : sysvinit
Database          : MySQL, PostgreSQL
Contributors      : @nielsbasjes, @axilleas, @mairin, @ponsjuh, @yorn, @psftw, @etcet, @mdirkse, @nszceta
Additional Notes  : In order to get a proper Ruby setup we build it from source
```

## Overview

Please read [requirements.md](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/requirements.md) for hardware and platform requirements.

### Important Notes

The following steps have been known to work and should be followed from up to bottom.
If you deviate from this guide, do it with caution and make sure you don't violate
any assumptions GitLab makes about its environment. We have also tried this on
RHEL 6.3 and found that there are subtle differences which are documented in part.
Look for the **RHEL Notes** note.

**This guide assumes that you run every command as root.**

#### If you find a bug

If you find a bug/error in this guide please submit an issue or a Merge Request
following the contribution guide (see [CONTRIBUTING.md](https://gitlab.com/gitlab-org/gitlab-recipes/blob/master/CONTRIBUTING.md)).

#### Security

Many setup guides of Linux software simply state: "disable selinux and firewall".
This guide does not disable any of them, we simply configure them as they were intended.
[Stop disabling SELinux](http://stopdisablingselinux.com/).

- - -

The GitLab installation consists of setting up the following components:

1. Install the base operating system (CentOS 6.5 Minimal) and Packages / Dependencies
2. Ruby
3. System Users
4. GitLab shell
5. Database
6. GitLab
7. Web server
8. Firewall

----------

## 1. Installing the operating system (CentOS 6.5 Minimal)

We start with a completely clean CentOS 6.5 "minimal" installation which can be
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

    wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6 https://www.fedoraproject.org/static/0608B895.txt
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

Verify that the key got installed successfully:

    rpm -qa gpg*
    gpg-pubkey-0608b895-4bd22942

Now install the `epel-release-6-8.noarch` package, which will enable EPEL repository on your system:

    rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

**Note:** Don't mind the `x86_64`, if you install on a i686 system you can use the same commands.

### Add PUIAS Computational repository

The [PUIAS Computational][PUIAS] repository is a part of [PUIAS/Springdale Linux][SDL],
a custom Red Hat&reg; distribution maintained by [Princeton University][PU] and the
[Institute for Advanced Study][IAS].  We take advantage of the PUIAS
Computational repository to obtain a git v1.8.x package since the base CentOS
repositories only provide v1.7.1 which is not compatible with GitLab.
Although the PUIAS offers an RPM to install the repo, it requires the
other PUIAS repos as a dependency, so you'll have to add it manually.

Create `/etc/yum.repos.d/PUIAS_6_computational.repo` and add the following lines:

    [PUIAS_6_computational]
    name=PUIAS computational Base $releasever - $basearch
    mirrorlist=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch/mirrorlist
    #baseurl=http://puias.math.ias.edu/data/puias/computational/$releasever/$basearch
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puias

Next download and install the gpg key.

    wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-puias http://springdale.math.ias.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-puias

Verify that the key got installed successfully:

    rpm -qa gpg*
    gpg-pubkey-41a40948-4ce19266

Verify that the EPEL and PUIAS Computational repositories are enabled as shown below:

    yum repolist

    repo id                 repo name                                                status
    PUIAS_6_computational   PUIAS computational Base 6 - x86_64                      2,018
    base                    CentOS-6 - Base                                          4,802
    epel                    Extra Packages for Enterprise Linux 6 - x86_64           7,879
    extras                  CentOS-6 - Extras                                           12
    updates                 CentOS-6 - Updates                                         814
    repolist: 15,525

If you can't see them listed, use the folowing command (from `yum-utils` package) to enable them:

    yum-config-manager --enable epel --enable PUIAS_6_computational

### Install the required tools for GitLab

    yum -y update
    yum -y groupinstall 'Development Tools'
    yum -y install vim-enhanced readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel gcc-c++ libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui redis sudo wget crontabs logwatch logrotate perl-Time-HiRes git patch

**RHEL Notes**

If some packages (eg. gdbm-devel, libffi-devel and libicu-devel) are NOT installed,
add the rhel6 optional packages repo to your server to get those packages:

    yum-config-manager --enable rhel-6-server-optional-rpms

Tip taken from [here](https://github.com/gitlabhq/gitlab-recipes/issues/62).

**Note:**
During this installation some files will need to be edited manually.
If you are familiar with vim set it as default editor with the commands below.
If you are not familiar with vim please skip this and keep using the default editor.

    # Install vim and set as default editor
    yum -y install vim-enhanced
    update-alternatives --set editor /usr/bin/vim.basic

    # For reStructuredText markup language support, install required package:
    yum -y install python-docutils

### Configure redis
Make sure redis is started on boot:

    chkconfig redis on
    service redis start

### Install mail server

In order to receive mail notifications, make sure to install a
mail server. The recommended one is postfix and you can install it with:

    yum -y install postfix

To use and configure sendmail instead of postfix see [Advanced Email Configurations](configure_email.md).

### Configure the default editor

You can choose between editors such as nano, vi, vim, etc.
In this case we will use vim as the default editor for consistency.

    ln -s /usr/bin/vim /usr/bin/editor
    
To remove this alias in the future:
    
    rm -i /usr/bin/editor


### Install Git from Source (optional)

Remove the system Git

    yum -y remove git

Install the pre-requisite files for Git compilation

    yum install zlib-devel perl-CPAN gettext curl-devel expat-devel gettext-devel openssl-devel
    
Download and extract Git 1.9.0

    mkdir /tmp/git && cd /tmp/git
    curl --progress https://git-core.googlecode.com/files/git-1.9.0.tar.gz | tar xz
    cd git-1.9.0/
    ./configure
    make
    make prefix=/usr/local install
    
Make sure Git is in your `$PATH`:

    which git
    
You might have to logout and login again for the `$PATH` to take effect.


----------

## 2. Ruby

The use of ruby version managers such as [RVM](http://rvm.io/), [rbenv](https://github.com/sstephenson/rbenv) or [chruby](https://github.com/postmodern/chruby) with GitLab in production frequently leads to hard to diagnose problems. Version managers are not supported and we stronly advise everyone to follow the instructions below to use a system ruby.

Remove the old Ruby 1.8 package if present. Gitlab 6.7 only supports the Ruby 2.0.x release series:

    yum remove ruby

Remove any other Ruby build if it is still present:

    cd <your-ruby-source-path>
    make uninstall

Download Ruby and compile it:

    mkdir /tmp/ruby && cd /tmp/ruby
    curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p451.tar.gz | tar xz
    cd ruby-2.0.0-p451
    ./configure --disable-install-rdoc
    make
    make prefix=/usr/local install

Install the Bundler Gem:

    gem install bundler --no-ri --no-rdoc

Logout and login again for the `$PATH` to take effect. Check that ruby is properly
installed with:

    which ruby
    # /usr/local/bin/ruby
    ruby -v
    # ruby 2.0.0p451 (2014-02-24 revision 45167) [x86_64-linux]

----------

## 3. System Users

Create a `git` user for Gitlab:

    adduser --system --shell /sbin/nologin --comment 'GitLab' --create-home --home-dir /home/git/ git

For extra security, the shell we use for this user does not allow logins via a terminal.

**Important:** In order to include `/usr/local/bin` to git user's PATH, one way is to edit the sudoers file. As root run:

    visudo

Then search for this line:

    Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin

and append `/usr/local/bin` like so:

    Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

Save and exit.

----------

## 4. GitLab shell

GitLab Shell is a ssh access and repository management application developed specifically for GitLab.


    # Go to home directory
    cd /home/git

    # Clone gitlab shell
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-shell.git -b v1.9.1

    cd gitlab-shell

    sudo -u git -H cp config.yml.example config.yml

    # Edit config and replace gitlab_url
    # with something like 'http://domain.com/'
    sudo -u git -H editor config.yml

    # Do setup
    sudo -u git -H /usr/local/bin/ruby ./bin/install

----------

## 5. Database

### 5.1 MySQL

Install `mysql` and enable the `mysqld` service to start on boot:

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
    CREATE USER 'git'@'localhost' IDENTIFIED BY 'supersecret';

    # Create the GitLab production database
    CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;

    # Grant the GitLab user necessary permissions on the table.
    GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'git'@'localhost';

    # Quit the database session
    \q

Try connecting to the new database with the new user:

    mysql -u git -p -D gitlabhq_production
    # Type the password you replaced supersecret with earlier
    # Quit the database session
    \q

### 5.2 PostgreSQL

Install `postgresql-server` and the `postgreqsql-devel` libraries:

    yum install postgresql-server postgresql-devel

Initialize the database:

    service postgresql initdb

Start the service and configure service to start on boot:

    service postgresql start
    chkconfig postgresql on

Configure the database user and password:

    su - postgres
    psql -d template1
    psql (8.4.13)

    template1=# CREATE USER git WITH PASSWORD 'your-password-here';
    CREATE ROLE
    template1=# CREATE DATABASE gitlabhq_production OWNER git;
    CREATE DATABASE
    template1=# \q
    exit # exit uid=postgres, return to root

Test the connection as the gitlab (uid=git) user. You should be root to begin this test:

    whoami
    
Attempt to log in to Postgres as the git user:

    sudo -u git psql -d gitlabhq_production -U git -W
    
If you see the following:

    gitlabhq_production=>

Your password has been accepted successfully and you can type \q to quit.


----------
## 6. GitLab

    # We'll install GitLab into home directory of the user "git"
    cd /home/git

### Clone the Source

    # Clone GitLab repository
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 6-6-stable gitlab

**Note:** You can change `6-6-stable` to `master` if you want the *bleeding edge* version, but do so with caution!

### Configure it

    cd /home/git/gitlab

    # Copy the example GitLab config
    sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

    # Make sure to change "localhost" to the fully-qualified domain name of your
    # host serving GitLab where necessary
    #
    # If you installed Git from source, change the git bin_path to /usr/local/bin/git
    sudo -u git -H editor config/gitlab.yml

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

    # Enable cluster mode if you expect to have a high load instance
    # Ex. change amount of workers to 3 for 2GB RAM server
    sudo -u git -H editor config/unicorn.rb

    # Copy the example Rack attack config
    sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

    # Configure Git global settings for git user, useful when editing via web
    # Edit user.email according to what is set in gitlab.yml
    sudo -u git -H git config --global user.name "GitLab"
    sudo -u git -H git config --global user.email "gitlab@localhost"
    sudo -u git -H git config --global core.autocrlf input

**Important Note:**
Make sure to edit both `gitlab.yml` and `unicorn.rb` to match your setup.

### Configure GitLab DB settings

    # For MySQL
    sudo -u git -H cp config/database.yml{.mysql,}

    # Make sure to update username/password in config/database.yml.
    # You only need to adapt the production settings (first part).
    # If you followed the database guide then please do as follows:
    # Change 'secure password' with the value you have given to $password
    # You can keep the double quotes around the password
    sudo -u git -H editor config/database.yml

    or

    # For PostgreSQL
    sudo -u git -H cp config/database.yml{.postgresql,}

    # Make config/database.yml readable to git only
    sudo -u git -H chmod o-rwx config/database.yml

### Install Gems

    cd /home/git/gitlab

    # For MySQL (note, the option says "without ... postgres")
    sudo -u git -H /usr/local/bin/bundle install --deployment --without development test postgres aws

    # Or for PostgreSQL (note, the option says "without ... mysql")
    sudo -u git -H bundle install --deployment --without development test mysql aws

### Initialize Database and Activate Advanced Features

    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

    # Type 'yes' to create the database tables.

    # When done you see 'Administrator account created:'

Type 'yes' to create the database.
When done you see 'Administrator account created:'

### Install Init Script

Download the init script (will be /etc/init.d/gitlab):

    wget -O /etc/init.d/gitlab https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/sysvinit/centos/gitlab-unicorn
    chmod +x /etc/init.d/gitlab
    chkconfig --add gitlab

Make GitLab start on boot:

    chkconfig gitlab on

### Set up logrotate

    cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

### Check Application Status

Check if GitLab and its environment are configured correctly:

    sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

### Start your GitLab instance:

    service gitlab start

### Compile assets

    sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production

## 7. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx.

### Nginx

You will need a new version of nginx otherwise you might encounter an issue like [this][issue-nginx].
To do so, follow the instructions provided by the [nginx wiki][nginx-centos] and then install nginx with:

    yum update
    yum -y install nginx
    chkconfig nginx on
    wget -O /etc/nginx/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/web-server/nginx/gitlab-ssl

Edit `/etc/nginx/conf.d/gitlab` and replace `git.example.com` with your FQDN. Make sure to read the comments in order to properly set up ssl.

Add `nginx` user to `git` group:

    usermod -a -G git nginx
    chmod g+rx /home/git/

Finally start nginx with:

    service nginx start

### Apache

We will configure apache with module `mod_proxy` which is loaded by default when
installing apache and `mod_ssl` which will provide ssl support:

    yum -y install httpd mod_ssl
    chkconfig httpd on
    wget -O /etc/httpd/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/web-server/apache/gitlab-ssl.conf
    mv /etc/httpd/conf.d/ssl.conf{,.bak}
    mkdir /var/log/httpd/logs/

Open `/etc/httpd/conf.d/gitlab.conf` with your editor and replace `git.example.org` with your FQDN. Also make sure the path to your certificates is valid.

Add `LoadModule ssl_module /etc/httpd/modules/mod_ssl.so` in `/etc/httpd/conf/httpd.conf`.

#### SELinux

To configure SELinux read the **SELinux modifications** section in [README](https://gitlab.com/gitlab-org/gitlab-recipes/blob/master/web-server/apache/README.md).

Finally, start apache:

    service httpd start

**Note:**
If you want to run other websites on the same system, you'll need to add in `/etc/httpd/conf/httpd.conf`:

    NameVirtualHost *:80
    <IfModule mod_ssl.c>
        # If you add NameVirtualHost *:443 here, you will also have to change
        # the VirtualHost statement in /etc/httpd/conf.d/gitlab.conf
        # to <VirtualHost *:443>
        NameVirtualHost *:443
        Listen 443
    </IfModule>

## 8. Configure the firewall

Poke an iptables hole so users can access the web server (http and https ports) and ssh.

    lokkit -s http -s https -s ssh

Restart the service for the changes to take effect:

    service iptables restart


## Done!

### Double-check Application Status

To make sure you didn't miss anything run a more thorough check with:

    cd /home/git/gitlab
    sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

Now, the output will complain that your init script is not up-to-date as follows:

    Init script up-to-date? ... no
      Try fixing it:
      Redownload the init script
      For more information see:
      doc/install/installation.md in section "Install Init Script"
      Please fix the error above and rerun the checks.

Do not mind about that error if you are sure that you have downloaded the up-to-date file from https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/sysvinit/centos/gitlab-unicorn and saved it to `/etc/init.d/gitlab`.

If all other items are green, then congratulations on successfully installing GitLab!
However there are still a few steps left.

## Initial Login

Visit YOUR_SERVER in your web browser for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    admin@local.host
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately change the password, so
nobody can access your GitLab by using this login information later on.

**Enjoy!**

## Links used in this guide

- [EPEL information](http://www.thegeekstuff.com/2012/06/enable-epel-repository/)
- [SELinux booleans](http://wiki.centos.org/TipsAndTricks/SelinuxBooleans)


[EPEL]: https://fedoraproject.org/wiki/EPEL
[PUIAS]: https://puias.math.ias.edu/wiki/YumRepositories6#Computational
[SDL]: https://puias.math.ias.edu
[PU]: http://www.princeton.edu/
[IAS]: http://www.ias.edu/
[keys]: https://fedoraproject.org/keys
[issue-nginx]: https://github.com/gitlabhq/gitlabhq/issues/5774
[nginx-centos]: http://wiki.nginx.org/Install#Official_Red_Hat.2FCentOS_packages
