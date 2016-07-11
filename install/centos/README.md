```
Distribution      : CentOS 6.8 Minimal
GitLab version    : 8.9
Web Server        : Apache, Nginx
Init system       : sysvinit
Database          : MySQL, PostgreSQL
Contributors      : @nielsbasjes, @axilleas, @mairin, @ponsjuh, @yorn, @psftw, @etcet, @mdirkse, @nszceta, @herkalurk, @mjmaenpaa
Additional Notes  : In order to get a proper Ruby & Git setup we build them from source
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

1. Install the base operating system (CentOS 6.8 Minimal) and Packages / Dependencies
1. Ruby
1. Go
1. System Users
1. Database
1. Redis
1. GitLab
1. Web server
1. Firewall

----------

## 1. Installing the operating system (CentOS 6.8 Minimal)

We start with a completely clean CentOS 6.8 "minimal" installation which can be
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

    wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6 https://getfedora.org/static/0608B895.txt
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

Verify that the key got installed successfully:

    rpm -qa gpg*
    gpg-pubkey-0608b895-4bd22942

Now install the `epel-release-6-8.noarch` package, which will enable EPEL repository on your system:

    rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

**Note:** Don't mind the `x86_64`, if you install on a i686 system you can use the same commands.

### Add Remi's RPM repository

[Remi's RPM Repository][REMI] is unofficial repository for Centos/RHEL that provides latest versions of some software. We take advantage of Remi's RPM repository to obtain up-to-date version of Redis.

Download the GPG key for Remi's repository and install it on your system:

    wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-remi http://rpms.famillecollet.com/RPM-GPG-KEY-remi
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-remi

Verify that the key got installed successfully:

    rpm -qa gpg*
    gpg-pubkey-00f97f56-467e318a

Now install the `remi-release-6` package, which will enable remi-safe repository on your system:

    rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

Verify that the EPEL and remi-safe repositories are enabled as shown below:

    yum repolist

    repo id        repo name                                                       status
    base           CentOS-6 - Base                                                  6696
    epel           Extra Packages for Enterprise Linux 6 - x86_64                  12125
    extras         CentOS-6 - Extras                                                  61
    remi-safe      Safe Remi's RPM repository for Enterprise Linux 6 - x86_64        827
    updates        CentOS-6 - Updates                                                137
    repolist: 19846

If you can't see them listed, use the folowing command (from `yum-utils` package) to enable them:

    yum-config-manager --enable epel --enable remi-safe

### Install the required tools for GitLab

    yum -y update
    yum -y groupinstall 'Development Tools'
    yum -y install readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui redis sudo wget crontabs logwatch logrotate perl-Time-HiRes git cmake libcom_err-devel.i686 libcom_err-devel.x86_64 nodejs

    # For reStructuredText markup language support, install required package:
    yum -y install python-docutils

**RHEL Notes**

If some packages (eg. gdbm-devel, libffi-devel and libicu-devel) are NOT installed,
add the rhel6 optional packages repo to your server to get those packages:

    yum-config-manager --enable rhel-6-server-optional-rpms

Tip taken from [here](https://github.com/gitlabhq/gitlab-recipes/issues/62).

### Install mail server

In order to receive mail notifications, make sure to install a
mail server. The recommended one is postfix and you can install it with:

    yum -y install postfix

To use and configure sendmail instead of postfix see [Advanced Email Configurations](../../e-mail/configure_email.md).

### Configure the default editor

During this installation some files will need to be edited manually.
You can choose between editors such as nano, vi, vim, etc.

In this case we will use vim as the default editor for consistency.
If you are familiar with vim set it as default editor with the commands below.

    # Install vim and set as default editor
    yum -y install vim-enhanced
    ln -s /usr/bin/vim /usr/bin/editor

To remove this alias in the future:

    rm -i /usr/bin/editor

### Install Git from Source

Make sure Git is version 2.7.4 or higher

    git --version

If not, install it from source. First remove the system Git:

    yum -y remove git

Install the pre-requisite files for Git compilation:

    yum install zlib-devel perl-CPAN gettext curl-devel expat-devel gettext-devel openssl-devel

Download and extract it:

    mkdir /tmp/git && cd /tmp/git
    curl --progress https://www.kernel.org/pub/software/scm/git/git-2.9.0.tar.gz | tar xz
    cd git-2.9.0
    ./configure
    make
    make prefix=/usr/local install

Make sure Git is in your `$PATH`:

    which git

You might have to logout and login again for the `$PATH` to take effect.
**Note:** When editing `config/gitlab.yml` (step 7), change the git `bin_path` to `/usr/local/bin/git`.

----------

## 2. Ruby

The use of ruby version managers such as [RVM](http://rvm.io/), [rbenv](https://github.com/sstephenson/rbenv) or [chruby](https://github.com/postmodern/chruby) with GitLab in production frequently leads to hard to diagnose problems. Version managers are not supported and we strongly advise everyone to follow the instructions below to use a system ruby.

Remove the old Ruby 1.8 package if present. GitLab only supports the Ruby 2.1 release series:

    yum remove ruby

Remove any other Ruby build if it is still present:

    cd <your-ruby-source-path>
    make uninstall

Download Ruby and compile it:

    mkdir /tmp/ruby && cd /tmp/ruby
    curl --progress https://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.9.tar.gz | tar xz
    cd ruby-2.1.9
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
    # ruby 2.1.10p492 (2016-04-01 revision 54464) [x86_64-linux]


----------

## 3. Go

Since GitLab 8.0, Git HTTP requests are handled by gitlab-workhorse (formerly gitlab-git-http-server). This is a small daemon written in Go. To install gitlab-workhorse we need a Go compiler.

    yum install golang golang-bin golang-src

----------

## 4. System Users

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

## 5. Database

### 5.1 PostgreSQL (recommended)

NOTE: because we need to make use of extensions we need at least pgsql 9.1 and the default 8.x on centos will not work.  We need to get the PGDG repositories enabled

If there are any previous versions remove them:

    yum remove postgresql

Install the pgdg repositories:

    rpm -Uvh http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-2.noarch.rpm

Install `postgresql93-server`, `postgreqsql93-devel` and the `postgresql93-contrib` libraries:

    yum install postgresql93-server postgresql93-devel postgresql93-contrib

Rename the service script:

    mv /etc/init.d/{postgresql-9.3,postgresql}

Initialize the database:

    service postgresql initdb

Start the service and configure service to start on boot:

    service postgresql start
    chkconfig postgresql on

Configure the database user and password:

    su - postgres
    psql -d template1

    psql (9.4.3)
    Type "help" for help.
    template1=# CREATE USER git CREATEDB;
    CREATE ROLE
    template1=# CREATE DATABASE gitlabhq_production OWNER git;
    CREATE DATABASE
    template1=# CREATE EXTENSION IF NOT EXISTS pg_trgm;
    template1=# \q
    exit # exit uid=postgres, return to root

Test the connection as the gitlab (uid=git) user. You should be root to begin this test:

    whoami

Attempt to log in to Postgres as the git user:

    sudo -u git psql -d gitlabhq_production

If you see the following:

    gitlabhq_production=>

your password has been accepted successfully and you can type \q to quit.

Check if the `pg_trgm` extension is enabled:

    SELECT true AS enabled
    FROM pg_available_extensions
    WHERE name = 'pg_trgm'
    AND installed_version IS NOT NULL;

If the extension is enabled this will produce the following output:

    enabled
    ---------
     t
     (1 row)

Ensure you are using the right settings in your `/var/lib/pgsql/9.3/data/pg_hba.conf`
to not get ident issues (you can use trust over ident):

    host    all             all             127.0.0.1/32            trust

Check the official [documentation][psql-doc-auth] for more information on
authentication methods.

### 5.2 MySQL

#### Note

We do not recommend using MySQL due to various issues. For example, case [(in)sensitivity](https://dev.mysql.com/doc/refman/5.0/en/case-sensitivity.html) and [problems](https://bugs.mysql.com/bug.php?id=65830) that [suggested](https://bugs.mysql.com/bug.php?id=50909) [fixes](https://bugs.mysql.com/bug.php?id=65830) [have](https://bugs.mysql.com/bug.php?id=63164).

#### MySQL

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

    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, DROP, INDEX, ALTER, LOCK TABLES, REFERENCES ON `gitlabhq_production`.* TO 'git'@'localhost';

Quit the database session:

    \q

Try connecting to the new database with the new user:

    sudo -u git -H mysql -u git -p -D gitlabhq_production

Type the password you replaced $password with earlier.
Quit the database session:

    \q

----------

## 6. Redis

GitLab requires at least Redis 2.8.

Remove old version:

    yum remove redis

Install new version from Remi's RPM repository:

    yum --enablerepo=remi,remi-test install redis

Make sure redis is started on boot:

    chkconfig redis on

Configure redis to use sockets:

    cp /etc/redis.conf /etc/redis.conf.orig

Disable Redis listening on TCP by setting 'port' to 0:

    sed 's/^port .*/port 0/' /etc/redis.conf.orig | sudo tee /etc/redis.conf

Enable Redis socket for default CentOS path:

    echo 'unixsocket /var/run/redis/redis.sock' | sudo tee -a /etc/redis.conf
    echo -e 'unixsocketperm 0770' | sudo tee -a /etc/redis.conf

Create the directory which contains the socket

    mkdir /var/run/redis
    chown redis:redis /var/run/redis
    chmod 755 /var/run/redis

Persist the directory which contains the socket, if applicable

    if [ -d /etc/tmpfiles.d ]; then
        echo 'd  /var/run/redis  0755  redis  redis  10d  -' | sudo tee -a /etc/tmpfiles.d/redis.conf
    fi

Activate the changes to redis.conf:

    service redis restart

Add git to the redis group:

    usermod -aG redis git

------

## 7. GitLab

    # We'll install GitLab into home directory of the user "git"
    cd /home/git

### Clone the Source

    # Clone GitLab repository
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 8-9-stable gitlab

**Note:** You can change `8-9-stable` to `master` if you want the *bleeding edge* version, but do so with caution!

### Configure it

    # Go to GitLab installation folder
    cd /home/git/gitlab

    # Copy the example GitLab config
    sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

    # Update GitLab config file, follow the directions at top of file
    sudo -u git -H editor config/gitlab.yml

    # Copy the example secrets file
    sudo -u git -H cp config/secrets.yml.example config/secrets.yml
    sudo -u git -H chmod 0600 config/secrets.yml

    # Make sure GitLab can write to the log/ and tmp/ directories
    sudo chown -R git log/
    sudo chown -R git tmp/
    sudo chmod -R u+rwX,go-w log/
    sudo chmod -R u+rwX tmp/

    # Make sure GitLab can write to the tmp/pids/ and tmp/sockets/ directories
    sudo chmod -R u+rwX tmp/pids/
    sudo chmod -R u+rwX tmp/sockets/

    # Create the public/uploads/ directory
    sudo -u git -H mkdir public/uploads/

    # Make sure only the GitLab user has access to the public/uploads/ directory
    # now that files in public/uploads are served by gitlab-workhorse
    sudo chmod 0700 public/uploads

    sudo chmod ug+rwX,o-rwx /home/git/repositories/

    # Change the permissions of the directory where CI build traces are stored
    sudo chmod -R u+rwX builds/

    # Change the permissions of the directory where CI artifacts are stored
    sudo chmod -R u+rwX shared/artifacts/

    # Copy the example Unicorn config
    sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

    # Find number of cores
    nproc

    # Enable cluster mode if you expect to have a high load instance
    # Ex. change amount of workers to 3 for 2GB RAM server
    # Set the number of workers to at least the number of cores
    sudo -u git -H editor config/unicorn.rb

    # Copy the example Rack attack config
    sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

    # Configure Git global settings for git user
    # 'autocrlf' is needed for the web editor
    sudo -u git -H git config --global core.autocrlf input

    # Disable 'git gc --auto' because GitLab already runs 'git gc' when needed
    sudo -u git -H git config --global gc.auto 0

    # Configure Redis connection settings
    sudo -u git -H cp config/resque.yml.example config/resque.yml

    # Change the Redis socket path if you are not using the default CentOS configuration
    sudo -u git -H editor config/resque.yml

**Important Note:** Make sure to edit both `gitlab.yml` and `unicorn.rb` to match your setup.

**Note:** If you want to use HTTPS, see [Using HTTPS][https] for the additional steps.

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

    # For PostgreSQL (note, the option says "without ... mysql")
    sudo -u git -H bundle config build.pg --with-pg-config=/usr/pgsql-9.3/bin/pg_config
    sudo -u git -H bundle install --deployment --without development test mysql aws kerberos

    # Or for MySQL (note, the option says "without ... postgres")
    sudo -u git -H bundle install --deployment --without development test postgres aws kerberos

**Note:** If you want to use Kerberos for user authentication, then omit `kerberos`
in the `--without` option above.

### Install GitLab shell

GitLab Shell is an SSH access and repository management software developed specially for GitLab.

    # Run the installation task for gitlab-shell (replace `REDIS_URL` if needed):
    sudo -u git -H bundle exec rake gitlab:shell:install[v3.0.0] REDIS_URL=unix:/var/run/redis/redis.sock RAILS_ENV=production

    # By default, the gitlab-shell config is generated from your main GitLab config.
    # You can review (and modify) the gitlab-shell config as follows:
    sudo -u git -H editor /home/git/gitlab-shell/config.yml

    # Ensure the correct SELinux contexts are set
    # Read http://wiki.centos.org/HowTos/Network/SecuringSSH
    restorecon -Rv /home/git/.ssh

**Note:** If you want to use HTTPS, see [Using HTTPS](#using-https) for the additional steps.

**Note:** Make sure your hostname can be resolved on the machine itself by either a
proper DNS record or an additional line in /etc/hosts ("127.0.0.1
hostname"). This might be necessary for example if you set up GitLab behind a
reverse proxy. If the hostname cannot be resolved, the final installation check
will fail with "Check GitLab API access: FAILED. code: 401" and pushing commits
will be rejected with "[remote rejected] master -> master (hook declined)".

### Install gitlab-workhorse

    cd /home/git
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-workhorse.git
    cd gitlab-workhorse
    sudo -u git -H git checkout v0.7.5
    sudo -u git -H make

### Initialize Database and Activate Advanced Features

    # Go to GitLab installation folder

    cd /home/git/gitlab

    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

    # Type 'yes' to create the database tables.

    # When done you see 'Administrator account created:'

**Note:** You can set the Administrator/root password and e-mail by supplying
  them in environmental variables, `GITLAB_ROOT_PASSWORD` and
  `GITLAB_ROOT_EMAIL` respectively, as seen below. If you don't set the
  password (and it is set to the default one) please wait with exposing GitLab
  to the public internet until the installation is done and you've logged into
  the server the first time. During the first login you'll be forced to change
  the default password.

    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=yourpassword GITLAB_ROOT_EMAIL=youremail

### Secure secrets.yml

The `secrets.yml` file stores encryption keys for sessions and secure variables.
Backup `secrets.yml` someplace safe, but don't store it in the same place as your
database backups. Otherwise your secrets are exposed if one of your backups is
compromised.

### Install Init Script

Download the init script (will be `/etc/init.d/gitlab`):

    cp lib/support/init.d/gitlab /etc/init.d/gitlab

And if you are installing with a non-default folder or user copy and edit the defaults file:

    cp lib/support/init.d/gitlab.default.example /etc/default/gitlab

If you installed GitLab in another directory or as a user other than the default you should change these settings in `/etc/default/gitlab`. Do not edit `/etc/init.d/gitlab` as it will be
changed on upgrade.

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

------

## 8. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx.

### Nginx

#### Installation

You will need a new version of nginx otherwise you might encounter an issue like [this][issue-nginx].
To do so, follow the instructions provided by the [nginx wiki][nginx-centos] and then install nginx with:

    yum update
    yum -y install nginx
    chkconfig nginx on

#### Site Configuration

    cp lib/support/nginx/gitlab /etc/nginx/conf.d/gitlab.conf

Make sure to edit the config file to match your setup:

    # Change YOUR_SERVER_FQDN to the fully-qualified
    # domain name of your host serving GitLab.

**Note:** If you want to use HTTPS, replace the `gitlab` Nginx config with `gitlab-ssl`. See [Using HTTPS](#using-https) for HTTPS configuration details.

Add `nginx` user to `git` group:

    usermod -a -G git nginx
    chmod g+rx /home/git/

#### Test Configuration

Validate your `gitlab` or `gitlab-ssl` Nginx config file with the following command:

    nginx -t

You should receive `syntax is okay` and `test is successful` messages. If you receive errors check your `gitlab` or `gitlab-ssl` Nginx config file for typos, etc. as indiciated in the error message given.


#### Restart

    service nginx restart

### Apache

Httpd can be configured with or without SSL support.  Please choose appropriate commands in next steps.

#### GitLab-Workhorse

Apache installation requires changes to gitlab-workhorse configuration. Change
`gitlab_workhorse_options` in `/etc/default/gitlab` to the following:

    gitlab_workhorse_options="-listenUmask 0 -listenNetwork tcp -listenAddr 127.0.0.1:8181 -authBackend http://127.0.0.1:8080"

And restart:

    service gitlab restart

#### HTTPS

We will configure apache with module `mod_proxy` which is loaded by default when
installing apache and `mod_ssl` which will provide ssl support:

    yum -y install httpd mod_ssl
    chkconfig httpd on
    wget -O /etc/httpd/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/web-server/apache/gitlab-ssl-apache22.conf
    mv /etc/httpd/conf.d/ssl.conf{,.bak}
    sed -i 's/logs\///g' /etc/httpd/conf.d/gitlab.conf

Open `/etc/httpd/conf.d/gitlab.conf` with your editor and replace `YOUR_SERVER_FQDN` with your FQDN. Also make sure the path to your certificates is valid.

Add `LoadModule ssl_module /etc/httpd/modules/mod_ssl.so` in `/etc/httpd/conf/httpd.conf`.

#### HTTP

We will configure apache with module `mod_proxy` which is loaded by default when
installing apache:

    yum -y install httpd
    chkconfig httpd on
    wget -O /etc/httpd/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/web-server/apache/gitlab-apache22.conf
    sed -i 's/logs\///g' /etc/httpd/conf.d/gitlab.conf

Open `/etc/httpd/conf.d/gitlab.conf` with your editor and replace `YOUR_SERVER_FQDN` with your FQDN.

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

------

## 9. Configure the firewall

Poke an iptables hole so users can access the web server (http and https ports) and ssh.

    lokkit -s http -s https -s ssh

Restart the service for the changes to take effect:

    service iptables restart

## Done!

### Double-check Application Status

To make sure you didn't miss anything run a more thorough check with:

    cd /home/git/gitlab
    sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

If all items are green, then congratulations on successfully installing GitLab!

**NOTE:** Supply `SANITIZE=true` environment variable to `gitlab:check` to omit project names from the output of the check command.

## Initial Login

If you didn't [provide a root password during setup](#initialize-database-and-activate-advanced-features),
you'll be redirected to a password reset screen to provide the password for the
initial administrator account. Enter your desired password and you'll be
redirected back to the login screen.

The default account's username is **root**. Provide the password you created
earlier and login. After login you can change the username if you wish.

**Enjoy!**

You can use `sudo service gitlab start` and `sudo service gitlab stop` to start and stop GitLab.

You can also check some [Advanced Setup Tips][tips].

## Links used in this guide

- [EPEL information](http://www.thegeekstuff.com/2012/06/enable-epel-repository/)
- [SELinux booleans](http://wiki.centos.org/TipsAndTricks/SelinuxBooleans)

[https]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md#using-https
[EPEL]: https://fedoraproject.org/wiki/EPEL
[REMI]: http://rpms.famillecollet.com/
[PUIAS]: https://puias.math.ias.edu/wiki/YumRepositories6#Computational
[SDL]: https://puias.math.ias.edu
[PU]: http://www.princeton.edu/
[IAS]: http://www.ias.edu/
[keys]: https://fedoraproject.org/keys
[issue-nginx]: https://github.com/gitlabhq/gitlabhq/issues/5774
[nginx-centos]: http://wiki.nginx.org/Install#Official_Red_Hat.2FCentOS_packages
[psql-doc-auth]: http://www.postgresql.org/docs/9.3/static/auth-methods.html
[tips]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md#advanced-setup-tips
