```
Distribution      : Fedora 20
GitLab version    : 7.1
Web Server        : Nginx
Init system       : systemd
Database          : PostgreSQL
Contributors      : @nielsbasjes, @axilleas, @mairin, @ponsjuh, @yorn, @psftw, @etcet, @mdirkse, @nszceta, @jmreyes
Additional Notes  : SMTP e-mail configuration
```

## Overview

Please read [requirements.md](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/requirements.md) for hardware and platform requirements.

### Important Notes

The following steps have been known to work and should be followed from up to bottom.
If you deviate from this guide, do it with caution and make sure you don't violate
any assumptions GitLab makes about its environment.

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

1. Base operating system (Fedora 20) and packages/dependencies
2. System users
3. Database
4. GitLab
5. Web server
6. Firewall

----------

## 1. Base operating system (Fedora 20) and packages/dependencies

We start with a completely clean Fedora 20 installation which can be
accomplished by downloading the appropriate installation iso file. Just boot the
system of the iso file and install the system.

### Updating and installing the required tools for Gitlab

    yum -y update
    yum -y groupinstall 'Development Tools'
    yum -y install readline readline-devel ncurses-devel gdbm-devel glibc-devel tcl-devel openssl-devel curl-devel expat-devel db4-devel byacc sqlite-devel libyaml libyaml-devel libffi libffi-devel libxml2 libxml2-devel libxslt libxslt-devel libicu libicu-devel system-config-firewall-tui redis sudo wget crontabs logwatch logrotate perl-Time-HiRes patch ruby ruby-devel

### Configure redis
Make sure redis is started on boot:

    systemctl enable redis
    systemctl start redis
    
### Install the Bundler Ruby gem

    gem install bundler --no-doc
    

### Configure the default editor

You can choose between editors such as nano, vi, vim, etc.
In this case we will use vim as the default editor for consistency.

    ln -s /usr/bin/vim /usr/bin/editor

To remove this alias in the future:

    rm -i /usr/bin/editor

----------

## 2. System users

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

## 3. Database

### PostgreSQL (recommended)

Install using yum:

    yum -y install postgresql-server postgresql-devel

Initialize the database:

    postgresql-setup initdb

Start the service and configure service to start on boot:

    systemctl enable postgresql
    systemctl start postgresql

Configure the database user and password:

    su - postgres
    psql -d template1

    psql (9.3.5)
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

Ensure you are using the right settings in your `/var/lib/pgsql/data/pg_hba.conf`
to not get ident issues (you can use trust over ident):

    host    all             all             127.0.0.1/32            trust

Check the official [documentation][psql-doc-auth] for more information on
authentication methods.

**Note on MySQL:**
If you wish to use MySQL instead of PostgreSQL, see indications in [CentOS guide](https://github.com/gitlabhq/gitlab-recipes/blob/master/install/centos/README.md#42-mysql). Note the changes needed to start the service due to `systemd`:

    systemctl enable mysqld
    systemctl start mysqld

----------
## 4. GitLab

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

### Configure e-mail

In order to receive mail notifications, you'll need to configure mail sending. We'll use SMTP directly.

```
# Change "config.action_mailer.delivery_method = :sendmail" to "config.action_mailer.delivery_method = :smtp"
sudo -u git -H editor /home/git/gitlab/config/environments/production.rb

sudo -u git -H cp /home/git/gitlab/config/initializers/smtp_settings.rb.sample /home/git/gitlab/config/initializers/smtp_settings.rb

# Edit the SMTP settings file with the appropriate information:
sudo -u git -H editor /home/git/gitlab/config/initializers/smtp_settings.rb
```

### Configure GitLab DB settings

    sudo -u git cp config/database.yml.postgresql config/database.yml

    # Make config/database.yml readable to git only
    sudo -u git -H chmod o-rwx config/database.yml
    
**Note on MySQL or remote PostgreSQL:**
See indications in [CentOS guide](https://github.com/gitlabhq/gitlab-recipes/blob/master/install/centos/README.md#configure-gitlab-db-settings).

### Install Gems

**Note:** As of bundler 1.5.2, you can invoke `bundle install -jN`
(where `N` the number of your processor cores) and enjoy the parallel gems installation with measurable
difference in completion time (~60% faster). Check the number of your cores with `nproc`.
For more information check this [post](http://robots.thoughtbot.com/parallel-gem-installing-using-bundler).
First make sure you have bundler >= 1.5.2 (run `bundle -v`) as it addresses some [issues](https://devcenter.heroku.com/changelog-items/411)
that were [fixed](https://github.com/bundler/bundler/pull/2817) in 1.5.2.

    cd /home/git/gitlab

    sudo -u git -H bundle config build.pg --with-pg-config=/usr/bin/pg_config
    sudo -u git -H bundle install --deployment --without development test mysql aws

**Note on MySQL:** Use only this instead (note, the option says "without ... postgres"):

    sudo -u git -H bundle install --deployment --without development test postgres aws

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

### Install startup services for systemd

Next we'll need to download the startup services files (see [here](https://github.com/gitlabhq/gitlab-recipes/tree/master/init/systemd) for details)

```
cd /etc/systemd/system/
wget -O gitlab-sidekiq.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-sidekiq.service
wget -O gitlab-unicorn.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-unicorn.service
wget -O gitlab.target https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab.target
```

We'll probably have to edit them in order to point to the right executables:
```
# Replace /usr/bin/bundle by /usr/local/bin/bundle in both files
editor /etc/systemd/system/gitlab-sidekiq.service
editor /etc/systemd/system/gitlab-unicorn.service
```

Another edit may be necessary since we used PostgreSQL:
```
# Replace mysqld.service by postgresql.service
editor /etc/systemd/system/gitlab.target
```

Reload systemd:

    systemctl --system daemon-reload

Enable the services to start at boot:

    systemctl enable gitlab.target gitlab-sidekiq gitlab-unicorn

### Set up logrotate

    cd /home/git/gitlab
    cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

### Check Application Status

Check if GitLab and its environment are configured correctly:

    sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

### Compile assets

    sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production

### Start your GitLab instance

    systemctl start gitlab-sidekiq gitlab-unicorn

## 5. Configure the web server

Use either Nginx or Apache, not both. Official installation guide recommends nginx, and it's the one covered here.

### Nginx

Install nginx with:

    yum update
    yum -y install nginx
    
    systemctl enable nginx
    
    # If not using SSL
    wget -O /etc/nginx/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-ce/raw/master/lib/support/nginx/gitlab

    # If using SSL
    wget -O /etc/nginx/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-ce/raw/master/lib/support/nginx/gitlab-ssl

Edit `/etc/nginx/conf.d/gitlab.conf` and replace `git.example.com` with your FQDN. Make sure to read the comments in order to properly set up SSL if needed.

Add `nginx` user to `git` group:

    usermod -a -G git nginx
    chmod g+rx /home/git/

Finally start nginx with:

    systemctl start nginx

## 6. Configure the firewall

Poke a firewalld hole so users can access the web server (http and https ports) and ssh.

    firewall-cmd --zone=public --add-service=ssh --permanent
    firewall-cmd --zone=public --add-service=http --permanent
    # If needed
    firewall-cmd --zone=public --add-service=https --permanent
    
Reload the firewall (needed since we used --permanent):

    firewall-cmd --reload

## Done!

### Double-check Application Status

To make sure you didn't miss anything run a more thorough check with:

    cd /home/git/gitlab
    sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

Now, the output will complain that your init script does not exist as follows:

    Init script exists? ... no
      Try fixing it:
      Install the init script
      For more information see:
      doc/install/installation.md in section "Install Init Script"
      Please fix the error above and rerun the checks.

Do not mind about that error, since it's looking for the sysvinit script and we're using systemd.

If all other items are green, then congratulations on successfully installing GitLab!

**NOTE:** Supply `SANITIZE=true` environment variable to `gitlab:check` to omit project names from the output of the check command.

## Initial Login

Visit YOUR_SERVER in your web browser for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    root
    5iveL!fe

**Enjoy!**

You can also check some [Advanced Setup Tips][tips].

[psql-doc-auth]: http://www.postgresql.org/docs/9.3/static/auth-methods.html
[tips]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md#advanced-setup-tips
