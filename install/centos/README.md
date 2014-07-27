```
Distribution      : CentOS 6.5 Minimal
GitLab version    : 6.0 - 7.1
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
Otherwise you can install git from source (instructions below).

Download PUIAS repo:

    wget -O /etc/yum.repos.d/PUIAS_6_computational.repo https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/install/centos/PUIAS_6_computational.repo

Next download and install the gpg key:

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
    yum -y install readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui redis sudo wget crontabs logwatch logrotate perl-Time-HiRes

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

To use and configure sendmail instead of postfix see [Advanced Email Configurations](e-mail/configure_email.md).

### Configure the default editor

You can choose between editors such as nano, vi, vim, etc.
In this case we will use vim as the default editor for consistency.

    ln -s /usr/bin/vim /usr/bin/editor

To remove this alias in the future:

    rm -i /usr/bin/editor


### Install Git from Source (optional)

Make sure Git is version 1.7.10 or higher, for example 1.7.12 or 1.8.4

    git --version

If not, install it from source. First remove the system Git:

    yum -y remove git

Install the pre-requisite files for Git compilation:

    yum install zlib-devel perl-CPAN gettext curl-devel expat-devel gettext-devel openssl-devel

Download and extract it:

    mkdir /tmp/git && cd /tmp/git
    curl --progress https://www.kernel.org/pub/software/scm/git/git-2.0.0.tar.gz | tar xz
    cd git-2.0.0/
    ./configure
    make
    make prefix=/usr/local install

Make sure Git is in your `$PATH`:

    which git

You might have to logout and login again for the `$PATH` to take effect.
**Note:** When editing `config/gitlab.yml` (step 6), change the git `bin_path` to `/usr/local/bin/git`.

----------

## 2. Ruby

The use of ruby version managers such as [RVM](http://rvm.io/), [rbenv](https://github.com/sstephenson/rbenv) or [chruby](https://github.com/postmodern/chruby) with GitLab in production frequently leads to hard to diagnose problems. Version managers are not supported and we strongly advise everyone to follow the instructions below to use a system ruby.

Remove the old Ruby 1.8 package if present. GitLab only supports the Ruby 2.0+ release series:

    yum remove ruby

Remove any other Ruby build if it is still present:

    cd <your-ruby-source-path>
    make uninstall

Download Ruby and compile it:

    mkdir /tmp/ruby && cd /tmp/ruby
    curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.1/ruby-2.1.2.tar.gz | tar xz
    cd ruby-2.1.2
    ./configure --disable-install-rdoc
    make
    make prefix=/usr/local install

Install the Bundler Gem:

    gem install bundler --no-doc

Logout and login again for the `$PATH` to take effect. Check that ruby is properly
installed with:

    which ruby
    # /usr/local/bin/ruby
    ruby -v
    # ruby 2.0.0p481 (2014-02-24 revision 45167) [x86_64-linux]

----------

## 3. System Users

Create a `git` user for Gitlab:

    adduser --system --shell /bin/bash --comment 'GitLab' --create-home --home-dir /home/git/ git

**Important:** In order to include `/usr/local/bin` to git user's PATH, one way is to edit the sudoers file. As root run:

    visudo

Then search for this line:

    Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin

and append `/usr/local/bin` like so:

    Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

Save and exit.


----------

## 4. Database

### 4.1 PostgreSQL (recommended)

NOTE: because we need to make use of extensions we need at least pgsql 9.1 and the default 8.x on centos will not work.  We need to get the PGDG repositories enabled

If there are any previous versions remove them:

    yum remove postgresql

Install the pgdg repositories:

    rpm -Uvh http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm

Install `postgresql93-server` and the `postgreqsql93-devel` libraries:

    yum install postgresql93-server postgresql93-devel

The executables are installed in `/usr/pgsql-9.3/bin/`. In order to be able to run them,
you have to either add this path to your `$PATH` or make symlinks. Here, we will make
symlinks to the commands used by GitLab:

    ln -s /usr/pgsql-9.3/bin/pg_dump /usr/bin/pg_dump
    ln -s /usr/pgsql-9.3/bin/pg_restore /usr/bin/pg_restore
    ln -s /usr/pgsql-9.3/bin/psql /usr/bin/psql

Rename the service script:

    mv /etc/init.d/{postgresql-9.3,postgresql}

Initialize the database:

    service postgresql initdb

Start the service and configure service to start on boot:

    service postgresql start
    chkconfig postgresql on

Configure the database user and password:

    su - postgres
    export PATH=$PATH:/usr/pgsql-9.3/bin/
    psql -d template1

    psql (9.4.3)
    Type "help" for help.
    template1=# CREATE USER git CREATEDB;
    CREATE ROLE
    template1=# CREATE DATABASE gitlabhq_production OWNER git;
    CREATE DATABASE
    template1=# \q
    exit # exit uid=postgres, return to root

Test the connection as the gitlab (uid=git) user. You should be root to begin this test:

    whoami

Attempt to log in to Postgres as the git user:

    sudo -u git psql -d gitlabhq_production

If you see the following:

    gitlabhq_production=>

your password has been accepted successfully and you can type \q to quit.

Ensure you are using the right settings in your `/var/lib/pgsql/9.3/data/pg_hba.conf`
to not get ident issues (you can use trust over ident):

    host    all             all             127.0.0.1/32            trust

Check the official [documentation][psql-doc-auth] for more information on
authentication methods.

### 4.2 MySQL

Install `mysql` and enable the `mysqld` service to start on boot:

    yum install -y mysql-server mysql-devel
    chkconfig mysqld on
    service mysqld start

Ensure you have MySQL version 5.5.14 or later:

    mysql --version

Secure your installation:

    mysql_secure_installation

Login to MySQL (type the database root password):

    mysql -u root -p


Create a user for GitLab (change $password in the command below to a real password you pick):

    CREATE USER 'git'@'localhost' IDENTIFIED BY '$password';

Ensure you can use the InnoDB engine which is necessary to support long indexes.
If this fails, check your MySQL config files (e.g. `/etc/mysql/*.cnf`, `/etc/mysql/conf.d/*`) for the setting "innodb = off".

    SET storage_engine=INNODB;

Create the GitLab production database:

    CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;

Grant the GitLab user necessary permissions on the table:

    GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'git'@'localhost';

Quit the database session:

    \q

Try connecting to the new database with the new user:

    sudo -u git -H mysql -u git -p -D gitlabhq_production

Type the password you replaced $password with earlier.
Quit the database session:

    \q

----------
## 5. GitLab

    # We'll install GitLab into home directory of the user "git"
    cd /home/git

### Clone the Source

    # Clone GitLab repository
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-1-stable gitlab

**Note:** You can change `7-1-stable` to `master` if you want the *bleeding edge* version, but do so with caution!

### Configure it

    cd /home/git/gitlab

    # Copy the example GitLab config
    sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

    # Make sure to change "localhost" to the fully-qualified domain name of your
    # host serving GitLab where necessary
    #
    # If you want to use https make sure that you set `https` to `true`. See #using-https for all necessary details.
    #
    # If you installed Git from source, change the git bin_path to /usr/local/bin/git
    sudo -u git -H editor config/gitlab.yml

    # Make sure GitLab can write to the log/ and tmp/ directories
    chown -R git {log,tmp}
    chmod -R u+rwX  {log,tmp}

    # Create directory for satellites
    sudo -u git -H mkdir /home/git/gitlab-satellites
    chmod u+rwx,g+rx,o-rwx /home/git/gitlab-satellites

    # Make sure GitLab can write to the tmp/pids/ and tmp/sockets/ directories
    chmod -R u+rwX  tmp/{pids,sockets}

    # Make sure GitLab can write to the public/uploads/ directory
    chmod -R u+rwX  public/uploads

    # Copy the example Unicorn config
    sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

    # Enable cluster mode if you expect to have a high load instance
    # Ex. change amount of workers to 3 for 2GB RAM server
    sudo -u git -H editor config/unicorn.rb

    # Copy the example Rack attack config
    sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

    # Configure Git global settings for git user, useful when editing via web
    # Edit user.email according to what is set in config/gitlab.yml
    sudo -u git -H git config --global user.name "GitLab"
    sudo -u git -H git config --global user.email "gitlab@localhost"
    sudo -u git -H git config --global core.autocrlf input

**Important Note:**
Make sure to edit both `gitlab.yml` and `unicorn.rb` to match your setup.

### Configure GitLab DB settings

    # PostgreSQL only:
    sudo -u git cp config/database.yml.postgresql config/database.yml

    # MySQL only:
    sudo -u git cp config/database.yml.mysql config/database.yml

    # MySQL and remote PostgreSQL only:
    # Update username/password in config/database.yml.
    # You only need to adapt the production settings (first part).
    # If you followed the database guide then please do as follows:
    # Change 'secure password' with the value you have given to $password
    # You can keep the double quotes around the password
    sudo -u git -H editor config/database.yml

    # PostgreSQL and MySQL:
    # Make config/database.yml readable to git only
    sudo -u git -H chmod o-rwx config/database.yml

### Install Gems

**Note:** As of bundler 1.5.2, you can invoke `bundle install -jN`
(where `N` the number of your processor cores) and enjoy the parallel gems installation with measurable
difference in completion time (~60% faster). Check the number of your cores with `nproc`.
For more information check this [post](http://robots.thoughtbot.com/parallel-gem-installing-using-bundler).
First make sure you have bundler >= 1.5.2 (run `bundle -v`) as it addresses some [issues](https://devcenter.heroku.com/changelog-items/411)
that were [fixed](https://github.com/bundler/bundler/pull/2817) in 1.5.2.

    cd /home/git/gitlab

    # For MySQL (note, the option says "without ... postgres")
    sudo -u git -H bundle install --deployment --without development test postgres aws

    # Or for PostgreSQL (note, the option says "without ... mysql")
    sudo -u git -H bundle config build.pg --with-pg-config=/usr/pgsql-9.3/bin/pg_config
    sudo -u git -H bundle install --deployment --without development test mysql aws

### Install GitLab shell

GitLab Shell is an ssh access and repository management software developed specially for GitLab.

```
# Go to the Gitlab installation folder:
cd /home/git/gitlab

# Run the installation task for gitlab-shell (replace `REDIS_URL` if needed):
sudo -u git -H bundle exec rake gitlab:shell:install[v1.9.6] REDIS_URL=redis://localhost:6379 RAILS_ENV=production

# By default, the gitlab-shell config is generated from your main gitlab config.
#
# Note: When using GitLab with HTTPS please change the following:
# - Provide paths to the certificates under `ca_file` and `ca_path options.
# - The `gitlab_url` option must point to the https endpoint of GitLab.
# - In case you are using self signed certificate set `self_signed_cert` to `true`.
# See #using-https for all necessary details.
#
# You can review (and modify) it as follows:
sudo -u git -H editor /home/git/gitlab-shell/config.yml

# Ensure the correct SELinux contexts are set
# Read http://wiki.centos.org/HowTos/Network/SecuringSSH
restorecon -Rv /home/git/.ssh
```

### Initialize Database and Activate Advanced Features

    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

Type **yes** to create the database.
When done you see **Administrator account created:**.

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

### Compile assets

    sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production

### Start your GitLab instance

    service gitlab start

## 6. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx.

### Nginx

You will need a new version of nginx otherwise you might encounter an issue like [this][issue-nginx].
To do so, follow the instructions provided by the [nginx wiki][nginx-centos] and then install nginx with:

    yum update
    yum -y install nginx
    chkconfig nginx on
    wget -O /etc/nginx/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-ce/raw/master/lib/support/nginx/gitlab-ssl

Edit `/etc/nginx/conf.d/gitlab.conf` and replace `git.example.com` with your FQDN. Make sure to read the comments in order to properly set up SSL.

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

## 7. Configure the firewall

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

**NOTE:** Supply `SANITIZE=true` environment variable to `gitlab:check` to omit project names from the output of the check command.

## Initial Login

Visit YOUR_SERVER in your web browser for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    root
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately change the password, so
nobody can access your GitLab by using this login information later on.

**Enjoy!**

You can also check some [Advanced Setup Tips][tips].

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
[psql-doc-auth]: http://www.postgresql.org/docs/9.3/static/auth-methods.html
[tips]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md#advanced-setup-tips
