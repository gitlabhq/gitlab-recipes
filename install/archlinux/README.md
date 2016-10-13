```
Distribution      : Arch Linux
GitLab version    : 6.7
Web Server        : nginx
Init system       : systemd
Database          : PostgreSQL
Contributors      : @nszceta
Additional Notes  : 
```

## Overview

Please read [requirements.md](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/requirements.md) for hardware and platform requirements.

### Important Notes

The following steps have been known to work and should be followed from up to bottom.
If you deviate from this guide, do it with caution and make sure you don't violate
any assumptions GitLab makes about its environment.

**This guide assumes that you run every command as root.**

** Never upgrade your packages blindly **

** Always test the effects of the package upgrade first and be prepared to downgrade if needed **

#### If you find a bug

If you find a bug/error in this guide please submit an issue or a Merge Request
following the contribution guide (see [CONTRIBUTING.md](https://gitlab.com/gitlab-org/gitlab-recipes/blob/master/CONTRIBUTING.md)).

The GitLab installation consists of setting up the following components:

1. Install the base operating system, packages, and dependencies
2. Ruby
3. System Users
4. GitLab shell
5. Database
6. GitLab
7. Web server
8. Firewall

----------

## 1. Installing the operating system

We start with a completely clean Arch Linux installation.

Make sure you have configured a static IP or otherwise dhcp is enabled as follows:

    systemctl enable dhcpcd
    systemctl start dhcpcd

Install the basic packages needed for Gitlab:

    pacman -Syu
    pacman -S base-devel vim readline ncurses gdbm glibc tcl openssl curl expat python2 bison sqlite \
    gcc libyaml libffi libxml2 libxslt redis sudo wget logwatch logrotate perl git patch openssh icu
    
### Configure redis
Make sure redis is started on boot:

    systemctl enable redis
    systemctl start redis

### Install mail server

In order to receive mail notifications, make sure to install a
mail server. The recommended one is postfix and you can install it with:

    pacman -S postfix

To use and configure sendmail instead of postfix see [Advanced Email Configurations](configure_email.md).

### Configure the default editor

You can choose between editors such as nano, vi, vim, etc.
In this case we will use vim as the default editor for consistency.

    ln -s /usr/bin/vim /usr/bin/editor
    
To remove this alias in the future:
    
    rm -i /usr/bin/editor

----------

## 2. Ruby

The use of ruby version managers such as [RVM](http://rvm.io/), [rbenv](https://github.com/sstephenson/rbenv) or [chruby](https://github.com/postmodern/chruby) with GitLab in production frequently leads to hard to diagnose problems. Version managers are not supported and we stronly advise everyone to follow the instructions below to use a system ruby.

    mkdir /tmp/ruby
    cd /tmp/ruby
    wget https://aur.archlinux.org/packages/ru/ruby2.0-headless/ruby2.0-headless.tar.gz
    pacman -S gdbm libffi libyaml openssl
    cd ruby2.0-headless
    makepkg --asroot
    pacman -U ruby2.0-headless-2.0.0_p451-2-x86_64.pkg.tar.xz
    ln -s /usr/bin/ruby-2.0 /usr/bin/ruby
    ruby --version
    # ruby 2.0.0p456 (2014-03-03) [x86_64-linux]
    
Install the Bundler Ruby Gem:

    mkdir /tmp/bundler
    cd /tmp/bundler
    wget https://aur.archlinux.org/packages/ru/ruby2.0-bundler/ruby2.0-bundler.tar.gz
    tar -zxf ruby2.0-bundler.tar.gz
    cd ruby2.0-bundler
    makepkg --asroot
    pacman -U ruby2.0-bundler-1.5.3-1-any.pkg.tar.xz
    ln -s /usr/bin/bundle-2.0 /usr/bin/bundle
    bundle --version
    # Bundler version 1.5.3
    ln -s /usr/bin/gem-2.0 /usr/bin/gem
    gem --version
    # 2.0.14
    ln -s /usr/bin/rake-2.0 /usr/bin/rake
    rake --version
    # rake, version 0.9.6
    
----------

## 3. System Users

Create a `git` user for Gitlab:

    userdel git
    useradd --system --shell /sbin/nologin --comment 'GitLab User' --create-home --home-dir /home/git/ git

For extra security, the shell we use for this user does not allow logins via a terminal.

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
    sudo -u git -H /usr/bin/ruby ./bin/install

----------

## 5. Database

### 5.1 PostgreSQL

Install Postgresql 9.1:

    mkdir /tmp/postgresql
    cd /tmp/postgresql
    wget https://aur.archlinux.org/packages/po/postgresql-9.1/postgresql-9.1.tar.gz
    makepkg --asroot
    pacman -U postgres*.tar.xz
    
    # If you get this message, accept the 'yes' resolution.
    # :: postgresql and postgresql-libs are in conflict. Remove postgresql-libs? [y/N] y

Initialize the database:

    mkdir /var/lib/postgres
    chown -R postgres:postgres /var/lib/postgres
    chmod -R 700 /var/lib/postgres
    su - postgres
    initdb --locale en_US.UTF-8 -E UTF8 -D '/var/lib/postgres/data'
    # return to the root user (from postgres user)
    logout
    systemctl start postgresql
    systemctl enable postgresql

Configure the database user and password:

    su - postgres
    psql -d template1
    # psql (9.1.13)

    template1=# CREATE USER git WITH PASSWORD 'your-password-here';
    CREATE ROLE
    template1=# CREATE DATABASE gitlabhq_production OWNER git;
    CREATE DATABASE
    template1=# \q
    
    # return to root user (from postgres user)
    logout

Test the connection as the gitlab (uid=git) user. You should be root to begin this test:

    whoami
    
Attempt to log in to Postgres as the git user:

    sudo -u git psql -d gitlabhq_production -U git -W
    
If you see the following:

    gitlabhq_production=>

Your password has been accepted successfully
Type \q to quit.

----------
## 6. GitLab

    # We'll install GitLab into home directory of the user "git"
    cd /home/git

### Clone the Source

    # Clone GitLab repository
    sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 6-7-stable gitlab

**Note:** You can change `6-7-stable` to `master` if you want the *bleeding edge* version, but do so with caution!

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
Make sure to edit both `gitlab.yml` and `unicorn.rb` (above) to match your setup.

### Configure GitLab DB settings

    # For PostgreSQL
    sudo -u git -H cp config/database.yml{.postgresql,}

    # Make config/database.yml readable to git only
    sudo -u git -H chmod o-rwx config/database.yml
    
Edit the password for the git user in `config/database.yml`

    sudo -u git -H editor config/database.yml

### Install Gems

    cd /home/git/gitlab

    # For PostgreSQL (note, the option says "without ... mysql")
    
    sudo -u git -H bundle install --deployment --without development test mysql aws

### Initialize Database and Activate Advanced Features

    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

    # Type 'yes' to create the database tables.

    # 'Administrator account created:' will appear when everything is finished.

Type 'yes' to create the database.
When done you see 'Administrator account created:'

### Install Init Script

Place `gitlab.target`, `gitlab-sidekiq.service`, and `gitlab-unicorn.service`
into the `/usr/lib/systemd/system/` folder.

    cp -v gitlab-sidekiq.service gitlab-unicorn.service gitlab.target /usr/lib/systemd/system/

Place `gitlab.logrotate` into the `/etc/logrotate.d/gitlab` folder.

    mkdir -p "/etc/logrotate.d/gitlab"
    cp -v gitlab.logrotate /etc/logrotate.d/gitlab

Copy `gitlab.tmpfiles.d` into the file `/usr/lib/tmpfiles.d/gitlab.conf`.

    mkdir -p "/usr/lib/tmpfiles.d"
    cp -v gitlab.tmpfiles.d "/usr/lib/tmpfiles.d/gitlab.conf"

Start services on startup:

    mkdir -p /var/run/gitlab/
    touch /var/run/gitlab/sidekiq.pid
    chmod 777 /var/run/gitlab/sidekiq.pid

    systemctl enable gitlab.target
    systemctl enable gitlab-sidekiq.service
    systemctl enable gitlab-unicorn.service
    
    systemctl start gitlab.target
    systemctl start gitlab-unicorn.service
    systemctl start gitlab-sidekiq.service

### Check Application Status

Check if GitLab and its environment are configured correctly:

    cd /home/git/gitlab
    sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

## Precompile assets

    sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production

## 7. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx.

### Nginx

You will need a new version of nginx otherwise you might encounter an issue like [this][issue-nginx].
To do so, follow the instructions provided by the [nginx wiki][nginx-centos] and then install nginx with:

    pacman -S nginx
    systemctl enable nginx
    mkdir "/etc/nginx/conf.d"
    
    wget -O /etc/nginx/conf.d/gitlab.conf \
    https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/web-server/nginx/gitlab-ssl
    
    echo "http { include /etc/nginx/conf.d/gitlab.conf; }" >> /etc/nginx/nginx.conf

Edit `/etc/nginx/conf.d/gitlab` and replace `git.example.com` with your FQDN. Make sure to read the comments in order to properly set up ssl.

Add `nginx` user to `git` group:

    usermod -a -G git http
    chmod g+rx /home/git/

Follow the instructions at the top of /etc/nginx/conf.d/gitlab.conf and generaate SSL certificates.

Finally start nginx with:

    systemctl start nginx

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

Do not mind about that error if you are sure that you have the correct systemd rules installed.

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

## Additional Information

[issue-nginx]: https://github.com/gitlabhq/gitlabhq/issues/5774


## Useful links

* [GitLab Wiki][]
* [GitLab PKGBUILD][]
* [gitlab-shell PKGBUILD][]


[GitLab Wiki]: https://wiki.archlinux.org/index.php/Gitlab
[GitLab PKGBUILD]: https://aur.archlinux.org/packages/gitlab
[gitlab-shell PKGBUILD]: https://aur.archlinux.org/packages/gitlab-shell
