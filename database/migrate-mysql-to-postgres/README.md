***The following howto assumes that you are running Debian 7 (wheezy)***

# Stop Gitlab

```bash
service gitlab stop
```

# Install postgresql

```bash
sudo apt-get install -y postgresql-9.1 postgresql-client libpq-dev
```

# Initial Setup

The following initial setup was taken from installation.md from the main installtion doc

```bash
# Login to PostgreSQL
sudo -u postgres psql -d template1

# Create a user for GitLab.
template1=# CREATE USER git;

# Create the GitLab production database & grant all privileges on database
template1=# CREATE DATABASE gitlabhq_production OWNER git;

# Quit the database session
template1=# \q

# Try connecting to the new database with the new user
sudo -u git -H psql -d gitlabhq_production
```

# Install postgres gem

```bash
cd ~git/gitlab
sudo -u git -H bundle install --deployment --without development test mysql aws
```

# Dump the mysql database

Make sure you do this as root, and therefore you will also need the root password for mysql as well

```bash
mysqldump --compatible=postgresql --default-character-set=utf8 -r /tmp/gitlabhq_production.mysql -u root -p gitlabhq_production
```

# Convert the mysql to postgres import

```bash
wget https://raw.github.com/lanyrd/mysql-postgresql-converter/master/db_converter.py -O /tmp/db_converter.py
python /tmp/db_converter.py /tmp/gitlabhq_production.mysql /tmp/gitlabhq_production.psql
```

***Note:*** This was tested using debian 7, with python 2.7.3

# Import the database

```bash
sudo -u git -H psql -d gitlabhq_production -f /tmp/gitlabhq_production.psql
```

# Update database config

```bash
cd ~git/gitlab/config
sudo -u git -H cp database.yml database.yml.backup
sudo -u git -H cp database.yml.postgresql database.yml
```

The defaults from the database.yml should work if you have not made any modifications to the postgres authentication. You may need to change database.yml to suite your config.

# Start Gitlab service

```bash
service gitlab start
service nginx restart
```

# Check application Status

Check if GitLab and its environment are configured correctly:

```bash
cd ~git/gitlab
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
```

To make sure you didn't miss anything run a more thorough check with:

```bash
cd ~git/gitlab
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
```

