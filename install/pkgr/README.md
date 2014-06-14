```
Distribution      : Ubuntu 14.04, Ubuntu 12.04, Debian 7.4
GitLab version    : 6.9+
Web Server        : Apache, Nginx
Init system       : upstart, sysvinit
Database          : PostgreSQL
Contributors      : @crohr
Additional Notes  : This install guide uses packages generated on https://packager.io
```

## Overview

This install guide makes use of prepackaged versions of Gitlab, available on <https://packager.io/gh/gitlabhq/gitlabhq>.

### Important Notes

The following steps have been known to work and should be followed from up to bottom.
If you deviate from this guide, do it with caution and make sure you don't violate
any assumptions GitLab makes about its environment.

#### If you find a bug

If you find a bug/error in this guide please submit an issue or a Merge Request
following the contribution guide (see [CONTRIBUTING.md](https://gitlab.com/gitlab-org/gitlab-recipes/blob/master/CONTRIBUTING.md)).
Should you encounter any issues regarding the pkgr.io package, please open an issue
starting with [pkgrio].

- - -

The GitLab installation consists of setting up the following components:

1. Install the package
1. Setup the peripheral services (mail, postgres, redis)
1. Configure the package
1. Web server
1. Maintenance

**This guide assumes that you run every command as root.**

## 1. Install the package

We assume that you're starting from a clean install of any of the supported distributions. Then, use the section dedicated to your distribution to install the package.

### Ubuntu Trusty 14.04

```shell
wget -qO - https://deb.packager.io/key | apt-key add -
echo "deb https://deb.packager.io/gh/gitlabhq/gitlabhq trusty 6-9-stable" | tee -a /etc/apt/sources.list.d/gitlab-ce.list
```

### Ubuntu Precise 12.04

```shell
wget -qO - https://deb.packager.io/key | apt-key add -
echo "deb https://deb.packager.io/gh/gitlabhq/gitlabhq precise 6-9-stable" | tee -a /etc/apt/sources.list.d/gitlab-ce.list
```

### Debian Wheezy 7.4

```shell
apt-get install -y apt-transport-https
wget -qO - https://deb.packager.io/key | apt-key add -
echo "deb https://deb.packager.io/gh/gitlabhq/gitlabhq wheezy 6-9-stable" | tee -a /etc/apt/sources.list.d/gitlab-ce.list
```

For all distributions, install the package by doing:

```shell
apt-get update
apt-get install gitlab-ce
```

## 2. Setup the peripheral services

GitLab needs a running mail server, redis server, and postgres server. Let's install that:

```shell
apt-get install -y postgresql postgresql-contrib redis-server postfix ruby1.9.1
```

Now create a new postgres user and database:

```shell
echo "CREATE USER \"user\" SUPERUSER PASSWORD 'pass';" | su - postgres -c psql && \
echo "CREATE DATABASE gitlab;" | su - postgres -c psql && \
echo "GRANT ALL PRIVILEGES ON DATABASE \"gitlab\" TO \"user\";" | su - postgres -c psql
```

## 3. Configure the package

All packages come with a command line utility to help with various aspects of GitLab. It closely mirrors the heroku toolbelt, so if you ever deployed an app on Heroku you should be at home.

In the rest of the guide, we will assume that the `SERVER_HOST` variable contains the hostname you will be using for GitLab. e.g. `SERVER_HOST=example.com`

Set the url corresponding to the database we just created:

    gitlab-ce config:set DATABASE_URL=postgres://user:pass@127.0.0.1/gitlab

Set the url to the redis server:

    gitlab-ce config:set REDIS_URL=redis://127.0.0.1:6379

Set the url to your GitLab server:

    gitlab-ce config:set GITLAB_URL="http://${SERVER_HOST}"

Set the port on which the ruby server will listen (defaults to 6000):

    gitlab-ce config:set PORT=6000

You can now configure `gitlab-shell`:

    gitlab-ce run rake gitlab:shell:install[v1.9.4]

Finally, initialize the database:

    gitlab-ce run rake db:schema:load db:seed_fu

And create the initialization scripts for the web and worker processes:

    gitlab-ce scale web=1 worker=1

## 4. Web Server

### NginX

```shell
apt-get install -y nginx

cat > /etc/nginx/sites-available/default <<EOF
server {
  listen          80;
  server_name     ${SERVER_HOST};
  location / {
    proxy_pass      http://localhost:6000;
  }
}
EOF

service nginx restart
```

### Apache

```shell
apt-get install -y apache2
sudo a2enmod proxy_http
# setup apache configuration
cat > /etc/apache2/sites-available/default <<EOF
<VirtualHost *:80>
  ServerName ${SERVER_HOST}
  <Location />
    ProxyPass http://localhost:6000/
  </Location>
</VirtualHost>
EOF
# restart apache
sudo service apache2 restart
```

## Done!

Visit SERVER_HOST in your web browser for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    root
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately change the password, so
nobody can access your GitLab by using this login information later on.

## Maintenance

If you wish to further configure GitLab, you can copy the example gitlab.yml configuration file to `/etc/gitlab-ce`, and edit it at your convenience. It will not be overwritten when you upgrade your GitLab installation:

    gitlab-ce run cp config/gitlab.yml /etc/gitlab-ce/ && chmod 0640 /etc/gitlab-ce/gitlab.yml
    vi /etc/gitlab-ce/gitlab.yml # edit any setting and save
    gitlab-ce config:set GITLAB_CONFIG=/etc/gitlab-ce/gitlab.yml
    service gitlab-ce restart

If you need to upgrade to a newer version, run the following commands:

    apt-get update
    apt-get install gitlab-ce
    gitlab-ce run rake db:migrate
    service gitlab-ce restart

Finally, have a look at what the command-line utility that ships with the package has to offer. It's a great way to interact with your package installation:

    gitlab-ce [run|scale|logs|config|config:set|config:get]

## Release cycle

New packages are automatically generated whenever code is pushed into the `6-9-stable` branch of GitLab, so once you're pinned to a specific branch, only backwards compatible changes should get into the packages. 

Whenever a new main branch is released (let's say `7-0-stable`), you can either modify your `gitlab-ce.list` file to upgrade, or just keep using the version you're pointing to.

If you're feeling adventurous and want to test the latest an greatest, you can also try pointing to `master` branch. Find out about all the latest releases at <https://packager.io/gh/gitlabhq/gitlabhq>.

**Enjoy!**
