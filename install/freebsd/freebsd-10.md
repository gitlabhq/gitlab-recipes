Installing GitLab on FreeBSD 10
===============================

##### Preface
Mileage with this guide may vary; different configurations of FreeBSD on
different hardware and with different packages may introduce other unexpected
issues. To make full use of this guide, read the [official GitLab installation guide](https://github.com/gitlabhq/gitlabhq/blob/7-6-stable/doc/install/installation.md)
before attempting anything in here.

**Note:** These steps were tested on a FreeBSD droplet at DigitalOcean.

1. Update system and Enable UTF-8
---------------------------------

Follow [this guide](https://www.b1c1l1.com/blog/2011/05/09/using-utf-8-unicode-on-freebsd/)
to enable UTF-8 on your system. This will allow you to create the GitLab
database later on.

Update your system:
```
pkg update
pkg upgrade
```

2. Install dependencies
-----------------------

Install system packages:
```
pkg install sudo bash icu cmake pkgconf git nginx node ruby ruby21-gems logrotate redis postgresql94-server postfix krb5
```

Install bundler gem system-wide:

```bash
gem install bundler --no-ri --no-rdoc
```

Add this to `/etc/rc.conf`:

```
# Core services
sshd_enable="YES"
ntpd_enable="YES"
ntpd_sync_on_start="YES"

# GitLab services
redis_enable="YES"
postgresql_enable="YES"
gitlab_enable="YES"

# Web server
nginx_enable="YES"

# Postfix/Sendmail
postfix_enable="YES"
sendmail_enable="NO"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
```

3. Create `git` user for GitLab
-------------------------------

Set up user and groups:

```
# Create user
pw add user -n git -m -s /usr/local/bin/bash -c "GitLab"

# Add 'git' user to 'redis' group (this will come in useful later!)
pw user mod git -G redis
```

4. Set up Postgres database
---------------------------

As root, make sure that Postgres is running:

```
service postgresql start
```

Check this with `service postgresql status`.

Set up the database:

```
# Log in to Postgres user account
su - pgsql

# Initialise Postgres db
initdb /usr/local/pgsql/data

# Connect to Postgres database
psql -d template1
```

When logged into the database:

```
# Create a user for GitLab
# Do not type the 'template1=#', this is part of the prompt
template1=# CREATE USER git CREATEDB;

# Create the GitLab production database & grant all privileges on database
template1=# CREATE DATABASE gitlabhq_production OWNER git encoding='UTF8';

# Quit the database session
template1=# \q
```

Then type `exit` to drop back to the `root` user.
Try connecting to the new database with the `git` user:

```
su - git
psql -d gitlabhq_production
```

If this succeeds, quit the database session by typing `\q` or hitting CTRL-D.

5. Install and set up Redis
---------------------------

Back up the original Redis config file:

```
cp /usr/local/etc/redis.conf /usr/local/etc/redis.conf.orig
```

Run the following commands to get Redis working:

```
# Disable Redis listening on TCP by setting 'port' to 0
sed 's/^port .*/port 0/' /usr/local/etc/redis.conf.orig | sudo tee /usr/local/etc/redis.conf

# Enable Redis socket
echo 'unixsocket /usr/local/var/run/redis/redis.sock' | sudo tee -a /usr/local/etc/redis.conf

# Grant permission to the socket to all members of the redis group
echo 'unixsocketperm 770' | sudo tee -a /usr/local/etc/redis.conf

# Create the directory which contains the socket
mkdir -p /usr/local/var/run/redis
chown redis:redis /usr/local/var/run/redis
chmod 755 /usr/local/var/run/redis

# Restart redis
sudo service redis restart
```

6. Install and set up GitLab
----------------------------

```
# Change to git home directory
cd /home/git

# Clone GitLab source
sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-7-stable gitlab

# Go to GitLab source folder
cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
```

Edit the GitLab configuration file
(`sudo -u git -H vim config/gitlab.yml`)
* The option `host:` should be set to your domain, e.g. "gitlab.mysite.com".
* The line `bin_path:` should be set to FreeBSD's `git` location: `/usr/local/bin/git`.
* Change /home/* to be /usr/home/*  (home is a symbolic link that doesn't work)

As root:

```
cd /home/git/gitlab
chown -R git log/
chown -R git tmp/
chmod -R u+rwX,go-w log/
chmod -R u+rwX tmp/

# Make folder for satellites and set the right permissions
sudo -u git -H mkdir /home/git/gitlab-satellites
sudo -u git -H chmod u+rwx,g=rx,o-rwx /home/git/gitlab-satellites

# Make sure GitLab can write to the tmp/pids/ and tmp/sockets/ directories
sudo -u git -H chmod -R u+rwX tmp/pids/
sudo -u git -H chmod -R u+rwX tmp/sockets/

# Make sure GitLab can write to the public/uploads/ directory
sudo -u git -H chmod -R u+rwX  public/uploads

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Set the number of workers to at least the number of cores
sudo -u git -H vim config/unicorn.rb

# Copy the example Rack attack config
sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "example@example.com"
sudo -u git -H git config --global core.autocrlf input

# Copy Redis connection settings
sudo -u git -H cp config/resque.yml.example config/resque.yml

# Configure Redis to use the modified socket path
# Change 'production' line to 'unix:/usr/local/var/run/redis/redis.sock'
sudo -u git -H vim config/resque.yml

# Copy database config
sudo -u git -H cp config/database.yml.postgresql config/database.yml

# Install Ruby Gems
sudo -u git -H bundle install --deployment --without development test mysql aws
```

7. GitLab Shell
---------------

```
# Run the rake task for installing gitlab-shell
sudo -u git -H bundle exec rake gitlab:shell:install[v2.4.1] REDIS_URL=unix:/usr/local/var/run/redis/redis.sock RAILS_ENV=production

# Edit the gitlab-shell config
# Change /home/* to be /usr/home/*  (home is a symbolic link that doesn't work)
# Change the 'socket' option to '/usr/local/var/run/redis/redis.sock'
# Change the 'gitlab_url' option to 'http://localhost:8080/'
# Don't bother configuring any SSL stuff in here because it's used internally
sudo -u git -H vim /home/git/gitlab-shell/config.yml
```

8. Initialise Database
----------------------

Initialize Database and Activate Advanced Features

```
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
# Type 'yes' to create the database tables.
# When done you see 'Administrator account created:'
```

**Note**: You can set the Administrator/root password by supplying it in the
environmental variable GITLAB_ROOT_PASSWORD as seen below. If you don't set the
password (and it is set to the default one) please wait with exposing GitLab to
the public internet until the installation is done and you've logged into the
server the first time. During the first login you'll be forced to change the
default password.

```
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=yourpassword
```

9. Init script
--------------

Download the FreeBSD init script as root:

```
wget -O /usr/local/etc/rc.d/gitlab https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/init/freebsd/gitlab-unicorn
```

10. Check Configuration and Compile Assets
------------------------------------------

```
cd /home/git/gitlab
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
```

If this all passes (all green and/or no errors are reported), then go ahead and
compile all of the assets for GitLab. This can take ~10-15 minutes on a
smaller machine, so don't panic if it takes a while!

```
sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production
```

11. Start GitLab service
------------------------

If all of the above steps complete with no errors and everything has gone
smoothly, then start the GitLab service.

As root:
```
service gitlab start
```

12. Nginx
---------

**Note:** The default version of `nginx` on FreeBSD is compiled without the
`gzip_static` module, which means you need to remove the appropriate directives
from the `nginx` configuration.

You might want to create `/usr/local/etc/nginx/conf.d/` and include it in
`nginx.conf` first.

```
wget -O /usr/local/etc/nginx/conf.d/gitlab.conf https://gitlab.com/gitlab-org/gitlab-ce/raw/master/lib/support/nginx/gitlab-ssl
```

Edit `/usr/local/etc/nginx/conf.d/gitlab.conf` and replace `git.example.com` with your FQDN. Make sure to read the comments in order to properly set up SSL.

Add `nginx` user to `git` group:

    pw usermod -a -G git nginx
    chmod g+rx /home/git/

Finally start nginx with:

    service nginx start

#### Test Configuration

Validate your `gitlab` or `gitlab-ssl` Nginx config file with the following command:

    nginx -t

You should receive `syntax is okay` and `test is successful` messages. If you
receive errors check your `gitlab` or `gitlab-ssl` Nginx config file for typos,
etc. as indiciated in the error message given.

Restart `nginx` with `sudo service nginx restart`, and you should be up and
running.

Good to Go
----------

Check everything with this command just to be sure:
```
cd /home/git/gitlab
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
```

If everything comes up green, then GitLab should work.

If some things show up as red, blue, pink or any colour that's not green - read any error messages thoroughly before trying any suggested fixes. Google comes in extremely handy when trying to diagnose unhelpful Ruby error messages.


Troubleshooting
===============

`504 - Gateway Timed Out` errors
--------------------------------

This can be caused by several different things with GitLab. The best bet is to
go back up through the install guide and check each step has been properly
executed.

* Check the logs! Look in `/home/git/gitlab/log` for clues.
* Check what's running! The command `sockstat -4l` usually gives an idea of
  which services are running on which ports. (Redis uses port `6379`,
  Unicorn uses port `8080`, and Postgres uses port `5432`).

What it usually boils down to:
    1. GitLab's assets haven't been precompiled (there is a command above)
    2. Postgres isn't running or the database isn't set up properly
    3. Redis isn't running
    4. Nginx isn't set up properly


Gem `timfel-krb5-auth` fails to build
-------------------------------------

Install the Kerberos package: `pkg install krb5`. As far as I know, there's no
way to disable the Kerberos authentication in GitLab (even if it's unused) so
unfortunately the only solution is to install the missing packages.

EDIT: The new version of timfel-krb5-auth fails to build even with `krb5` installed. The only solution is to change the package version to `0.8.2`. [(More info here)](https://github.com/gitlabhq/gitlabhq/issues/8478#issuecomment-71328552)


Postfix/sendmail: "postdrop: warning: unable to look up public/pickup: No such file or directory"
-------------------------------------------------------------------------------------------------

Sometimes Postfix and/or sendmail might complain if they're not set up
correctly or have only just been installed.

```
mkfifo /var/spool/postfix/public/pickup
killall $(pgrep sendmail) # Kill all sendmail processes
sudo service postfix restart # Restart Postfix
```
[(Source)](http://www.databasically.com/2009/12/02/ubuntu-postfix-error-postdrop-warning-unable-to-look-up-publicpickup-no-such-file-or-directory/)


Unicorn / nginx: "Failed to set accept\_filter=httpready"
---------------------------------------------------------

This is to do with an HTTP buffering kernel module in FreeBSD that some HTTP
servers expect to be loaded. Run this:
```
kldload accf_http
echo 'accf_http_load="YES"' >> /boot/loader.conf

sudo service gitlab restart
sudo service redis restart
sudo service nginx restart
```
[(Source)](http://www.cyberciti.biz/faq/failed-to-enable-the-httpready-accept-filter/)

PostgreSQL: "FATAL: could not create shared memory segment: Function not implemented"
-------------------------------------------------------------------------------------

You're trying to run PostgreSQL in a FreeBSD jail, which needs some sysctl tweaks. Set the following options in your jail's config (assuming you're using ezjail):
```
export jail_**MY_JAIL_NAME**_parameters="allow.raw_sockets=1 allow.sysvipc=1"
```
[(Source)](https://dan.langille.org/2013/07/09/fatal-could-not-create-shared-memory-segment-function-not-implemented/)

References
==========

* [GitLab official installation guide](https://github.com/gitlabhq/gitlabhq/blob/7-6-stable/doc/install/installation.md)
* [Luiz Gustavo's GitLab/FreeBSD guide (Portuguese)](http://www.luizgustavo.pro.br/blog/2014/08/21/instalacao-gitlab-no-freebsd/)
