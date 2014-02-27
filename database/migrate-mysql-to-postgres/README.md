# Stop Gitlab

```bash
service gitlab stop
```

# Install postgresql

```bash
sudo apt-get install -y postgresql-9.1 postgresql-client libpq-dev
```

# Initial Setup

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

```bash
mysqldump --compatible=postgresql --default-character-set=utf8 -r /tmp/gitlabhq_production.mysql -u root -p gitlabhq_production
```

# Convert the mysql to postgres import

```bash
wget https://raw.github.com/lanyrd/mysql-postgresql-converter/master/db_converter.py -O /tmp/db_converter.py
python db_converter.py /tmp/gitlab_production.mysql /tmp/gitlab_production.psql
```

# Import the database

```bash
sudo -u git -H psql -d gitlabhq_production -f /tmp/gitlab_production.psql
```

# Update database config

```bash
cd ~git/gitlab/config
sudo -u git -H cp database.yml database.yml.backup
sudo -u git -H cp database.yml.postgresql database.yml
```

# Start Gitlab service

```bash
service gitlab start
service nginx restart
```
