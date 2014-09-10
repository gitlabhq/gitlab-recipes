# Usage of PostgreSQL 9.3

```
Distribution      : Debian Wheezy
GitLab version    : 7.x
Database          : PostgreSQL
Contributors      : @bionix
```

This recipe shows how to upgrade the PostrgreSQL database from version 9.1 to 9.3.
It is **strongly recommended** to take a [backup][] of your GitLab database before
following the next steps.

## Install PostgreSQL 9.3

Install the [official PostgreSQL Debian/Ubuntu repository][apt]:

    cat >> /etc/apt/sources.list.d/pgdg.list << EOF
    deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main
    EOF

Install the repository signing key:

    sudo apt-get install wget ca-certificates
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

Update your apt lists:

    sudo apt-get update

Upgrade your installed packages:

    sudo apt-get upgrade

## Intregation in the manual installation process

If you arrive the point 4 in the manual [4. Database][db-manual], replace the
first step with the following command:

    sudo apt-get install -y postgresql-9.3 postgresql-client-9.3 libpq-dev

After that, follow the normal manual instructions.

## Upgrade from PostgreSQL version 9.1 to 9.3

Stop your Gitlab service:

    sudo service gitlab stop

Install all PostgreSQL packages for your environment:

    sudo apt-get install -y postgresql-9.3 postgresql-server-dev-9.3 postgresql-contrib-9.3 postgresql-client-9.3 libpq-dev

Extend your PostgreSQL 9.3. server with your extensions:

    sudo su - postgres -c "psql template1 -p 5433 -c 'CREATE EXTENSION IF NOT EXISTS hstore;'"
    sudo su - postgres -c "psql template1 -p 5433 -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'"

Stop your PostgreSQL server daemons (both!):

    sudo service postgresql stop

Make the migration from 9.1 to 9.3:

    sudo su - postgres -c '/usr/lib/postgresql/9.3/bin/pg_upgrade \
                            -b /usr/lib/postgresql/9.1/bin \
                            -B /usr/lib/postgresql/9.3/bin \
                            -d /var/lib/postgresql/9.1/main/ \
                            -D /var/lib/postgresql/9.3/main/ \
                            -O " -c config_file=/etc/postgresql/9.3/main/postgresql.conf" \
                            -o " -c config_file=/etc/postgresql/9.1/main/postgresql.conf"'

Remove your old PostgreSQL version, if you have no issues:

    sudo apt-get remove -y postgresql-9.1

Change the listen port of your PostgreSQL 9.3 server:

    sudo sed -i "s:5433:5432:g" /etc/postgresql/9.3/main/postgresql.conf

Start your PostgreSQL service:

    sudo service postgresql start

Start your Gitlab service:

    sudo service gitlab start

Done!

[backup]: http://doc.gitlab.com/ce/raketasks/backup_restore.html
[apt]: https://wiki.postgresql.org/wiki/Apt
[db-manual]: https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md#4-database
