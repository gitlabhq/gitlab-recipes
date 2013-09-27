#!/bin/bash
#
# Interactive Install Script for GitLab 6.1 on Ubuntu 12.04-14.04
# by doublerebel
# https://github.com/doublerebel/gitlab-recipes/blob/master/install/ubuntu/ubuntu_server_1204.sh
#
# Usage: $0 [--url <yourgitlabdomain.com>] [--db <mysql|postgres>] [--gitlab <version>] [--shell <version>]
# Requires --url parameter
# Default database is postgres
#
# If installation fails, script can be re-run safely.
#
#
# Distribution      : Ubuntu 12.04/12.10/13.04/13.10/14.04
# GitLab version    : 7.0
# Web Server        : nginx (optional)
# Init system       : init.d
# Database          : MySQL or Postgres
# Contributors      : doublerebel
# Additional Notes  : the script uses ppa:brightbox/ruby-ng-experimental to install ruby

# OPTIONS
GITLAB_URL="default.com"
DB_TYPE="postgres"
NUM_PROCS=$(nproc)

# VERSIONS
GITLAB_VERSION="7-0-stable"
GITLAB_SHELL_VERSION="1.9.6"
RUBY_PACKAGES="ruby2.0 ruby2.0-dev"
CHARLOCK_HOLMES_VERSION="0.6.9.4"


# GITLAB INSTALLATION
SCRIPT_DIR=$PWD
VALID_RELEASES="precise trusty wheezy"
THIS_RELEASE=$(lsb_release -sc)

head() {
  echo ""
  echo "#####################################"
  echo "=== $1 ==="
}
head "Beginning GitLab Installation"


# PARSE ANY COMMAND LINE FLAGS
echo "Parsing arguments..."
usage() {
    echo "Usage: $0 [--url <yourgitlabdomain.com>] [--db <mysql|postgres>] [--gitlab <version>] [--shell <version>]" 1>&2;
    exit 1;
}

remove_db_user() {
    echo "Dropping gitlab@localhost from database..."
    echo "DROP USER 'gitlab'@'localhost'" | mysql -u root -p
}


if ! ARGS=$(getopt -n "$0" -o hru:d:p:g:s: --long help,remove-db-user,url:,db:,gitlab:,shell: -- "$@"); then
    echo "Error parsing command line arguments" 1>&2;
    exit 1;
fi
eval set -- "$ARGS"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -r|--remove-db-user)
            remove_db_user
            exit 0;
            ;;
        -u|--url)
            if [[ ! "$2" =~ "-" ]]; then
                GITLAB_URL="$2"
            fi
            shift 2;
            ;;
        -d|--db)
            DB_TYPE="$2"
            ((DB_TYPE == "mysql" || DB_TYPE == "postgres")) || usage
            shift 2;
            ;;
        -g|--gitlab)
            GITLAB_VERSION="$2"
            shift 2;
            ;;
        -s|--shell)
            GITLAB_SHELL_VERSION="$2"
            shift 2;
            ;;
        *)
            break
            ;;
    esac
done

echo "Arguments parsed."

if [ -z "${GITLAB_URL}" ] || [ $GITLAB_URL == "default.com" ]; then
    echo "Non-default non-empty URL is required" 1>&2;
    usage
fi


################
# PREREQUISITES
head "1. Packages / Dependencies"

ask_about_release() {
    echo "The current release $THIS_RELEASE is not officially supported by this script."
    read -p "Supported releases are: $VALID_RELEASES.  Continue (yes/no)?" choice
    case "$choice" in
        y|Y|yes|Yes)
            echo "Continuing at your own risk.  If this works, let us know!"
            ;;
        n|N|no|No)
            echo "Please choose Ubuntu Precise, Ubuntu Trusty, or Debian Wheezy for installation." 1>&2;
            exit 1;
            ;;
        *)
            echo "Error: invalid input $choice"
            ask_about_release
            ;;
    esac
}

# Packager.io requirement: Check for Ubuntu Precise, Ubuntu Trusty, or Debian Wheezy
# if [[ ! $VALID_RELEASES =~ $THIS_RELEASE ]]; then
#     ask_about_release
# fi



echo "Installing git, ssh, redis, postfix, checkinstall, sudo, makepasswd, and charlock_holmes and nokogiri dependencies..."

CHARLOCK_DEPENDENCIES="libicu-dev"
NOKOGIRI_DEPENDENCIES="libxml2-dev libxslt-dev"
apt-get install -y wget curl git-core openssh-server redis-server postfix checkinstall sudo makepasswd $CHARLOCK_DEPENDENCIES $NOKOGIRI_DEPENDENCIES


################
# RUBY
head "2. Ruby"

install_ruby_from_ppa() {
    echo "Adding Brightbox PPA..."
    apt-get install -y software-properties-common python-software-properties
    add-apt-repository -y ppa:brightbox/ruby-ng-experimental
    apt-get update
    echo "Installing Ruby..."
    apt-get install -y $RUBY_PACKAGES
}

ask_about_ruby() {
    read -p "Install Ruby 2.x from Brightbox PPA (yes/no)? " choice
    case "$choice" in
        y|Y|yes|Yes)
            install_ruby_from_ppa
            ;;
        n|N|no|No)
            echo "Ruby 2.x is required.  Please restart installation after Ruby 2.x is available." 1>&2;
            exit 1;
            ;;
        *)
            echo "Error: invalid input $choice"
            ask_about_ruby
            ;;
    esac
}

echo "Checking Ruby version..."
if [[ -z $(which ruby) ]] || [[ ! $(ruby --version) =~ "ruby 2." ]]; then
    echo "Ruby 2.x not installed"
    ask_about_ruby
fi

echo "Installing bundler..."
gem install bundler --no-ri --no-rdoc


################
# GIT USER
head "3. System Users"

run_as_git_user() {
    sudo -u git -H "$@"
}

echo "Adding git user..."
adduser --disabled-login --gecos 'GitLab' git
run_as_git_user git config --global user.name GitLab
run_as_git_user git config --global user.email gitlab@$GITLAB_URL
run_as_git_user git config --global core.autocrlf input

# DATABASE
echo "Creating secure database password..."
DB_GITLAB_USER_PASSWORD=$(makepasswd --char=10)
if [ $DB_TYPE = "mysql" ]; then
    echo mysql-server mysql-server/root_password password $DB_GITLAB_USER_PASSWORD | debconf-set-selections
    echo mysql-server mysql-server/root_password_again password $DB_GITLAB_USER_PASSWORD | debconf-set-selections
elif [ $DB_TYPE = "postgres" ]; then
    echo postgres-server postgres-server/root_password password $DB_GITLAB_USER_PASSWORD | debconf-set-selections
    echo postgres-server postgres-server/root_password_again password $DB_GITLAB_USER_PASSWORD | debconf-set-selections
fi

ask_about_db_user() {
    read -p "Drop gitlab@localhost from database (yes/no)? " choice
    case "$choice" in
        y|Y|yes|Yes)
            remove_db_user
            echo "Retrying database user initilization..."
            cat $SCRIPT_DIR/gitlab-mysql.sql | sed s/\$password/$DB_GITLAB_USER_PASSWORD/ | mysql -u root -p
            ;;
        n|N|no|No)
            echo "Unable to initialize GitLab database user.  Installation may not complete correctly." 1>&2;
            ;;
        *)
            echo "Error: invalid input $choice"
            ask_about_db_user
            ;;
    esac
}

if [ $DB_TYPE = "mysql" ]; then
    if [[ -z $(which mysql) ]]; then
        echo "MySQL not installed"
        echo "Installing MySQL..."
        apt-get install -y mysql-server mysql-client
    else
        echo "MySQL detected as installed"
    fi

    echo "Installing mysql-dev for gems..."
    apt-get install -y libmysqlclient-dev

    echo "Initializing GitLab database..."
    cat $SCRIPT_DIR/gitlab-mysql.sql | sed s/\$password/$DB_GITLAB_USER_PASSWORD/ | mysql -u root
    if [[ ! $? -eq 0 ]]; then
        echo "MySQL root password exists, retrying..."
        cat $SCRIPT_DIR/gitlab-mysql.sql | sed s/\$password/$DB_GITLAB_USER_PASSWORD/ | mysql -u root -p
    fi
    if [[ ! $? -eq 0 ]]; then
        ask_about_db_user
    fi

elif [ $DB_TYPE = "postgres" ]; then
    if [[ -z $(which psql) ]]; then
        echo "Postgres not installed"
        echo "Installing Postgres..."
        apt-get install -y postgresql-9.1 postgresql-client
    else
        echo "Postgres detected as installed"
    fi

    echo "Installing libpq-dev for gems..."
    apt-get install -y libpq-dev

    echo "Initializing GitLab database..."
    cat $SCRIPT_DIR/gitlab-postgres.sql | sed s/\$password/$DB_GITLAB_USER_PASSWORD/ | sudo -u postgres psql -d template1

    # echo "Checking git user connection to GitLab database..."
    # run_as_git_user psql -d gitlabhq_production
fi


################
# GITLAB SOURCE
head "4. Database"
echo "Delaying Database until GitLab available..."


head "5. GitLab"

# echo "Adding packager.io repo..."
# wget -qO - https://deb.packager.io/key | apt-key add -
# echo "deb https://deb.packager.io/gh/gitlabhq/gitlabhq $THIS_RELEASE 7-0-stable" | tee -a /etc/apt/sources.list.d/gitlab-ce.list
# apt-get update

# echo "Installing GitLab from packager.io..."
# apt-get install gitlab-ce

echo "Retrieving GitLab source..."
cd /home/git
run_as_git_user git clone -b $GITLAB_VERSION https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab

echo "Setting GitLab URL to $GITLAB_URL"
run_as_git_user cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
run_as_git_user cp config/unicorn.rb.example config/unicorn.rb
run_as_git_user cp config/gitlab.yml.example config/gitlab.yml
run_as_git_user sed -i.bak s/localhost/$GITLAB_URL/g config/gitlab.yml


head "5b. GitLab Shell"

echo "Installing gitlab-shell v$GITLAB_SHELL_VERSION using rake task..."
cd /home/git/gitlab
run_as_git_user bundle exec rake gitlab:shell:install[v$GITLAB_SHELL_VERSION] REDIS_URL=redis://localhost:6379 RAILS_ENV=production


################
# DB CONFIGURE
head "4. Database"

echo "Copying database configuration..."
if [ $DB_TYPE = "mysql" ]; then
    run_as_git_user cp config/database.yml.mysql config/database.yml
elif [ $DB_TYPE = "postgres" ]; then
    run_as_git_user cp config/database.yml.postgresql config/database.yml
fi

echo "Inserting secure database password into configuration..."
run_as_git_user sed -i.bak s/root/gitlab/g config/database.yml
run_as_git_user sed -i.bak s/"secure\spassword"/$DB_GITLAB_USER_PASSWORD/g config/database.yml
run_as_git_user chmod o-rwx config/database.yml

echo "Installing charlock_holmes $CHARLOCK_HOLMES_VERSION..."
gem install charlock_holmes --version $CHARLOCK_HOLMES_VERSION

echo "Installing database bundle..."
if [ $DB_TYPE = "mysql" ]; then
    run_as_git_user bundle install -j$NUM_PROCS --deployment --without development test postgres aws
elif [ $DB_TYPE = "postgres" ]; then
    run_as_git_user bundle install -j$NUM_PROCS --deployment --without development test mysql aws
fi

echo "Setting up database bundle..."
run_as_git_user bundle exec rake gitlab:setup RAILS_ENV=production


################
# GITLAB PERMISSIONS
head "6. GitLab (continued)"

set_perms() {
    chmod u+rwX "$@"
}

create_and_set_perms() {
    run_as_git_user mkdir $@
    set_perms "$@"
}

echo "Creating GitLab directories and setting permissions..."
chown -R git {log,tmp}
set_perms {log,tmp}

run_as_git_user mkdir /home/git/gitlab-satellites
chmod u+rwx,g=rx,o-rwx /home/git/gitlab-satellites
create_and_set_perms tmp/{pids,sockets}
create_and_set_perms public/uploads

# INIT SCRIPT
echo "Installing GitLab init script..."
cp lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab
update-rc.d gitlab defaults 21

echo "Setting up logrotate..."
cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

# CHECK ENVIRONMENT
echo "Checking GitLab environment..."
run_as_git_user bundle exec rake gitlab:env:info RAILS_ENV=production

echo "Precompiling GitLab assets..."
run_as_git_user bundle exec rake assets:precompile RAILS_ENV=production


################
# NGINX
head "7. Nginx"

install_nginx() {
    echo "Installing Nginx...";
    apt-get install -y nginx-light
    cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
    ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
    sed -i.bak s/YOUR_SERVER_FQDN/$GITLAB_URL/g /etc/nginx/sites-available/gitlab
    service nginx restart
}

ask_about_nginx() {
    read -p "Install Nginx and site config (yes/no)? " choice
    case "$choice" in
        y|Y|yes|Yes)
            install_nginx
            ;;
        n|N|no|No)
            echo "Not installing Nginx.";
            ;;
        *)
            echo "Error: invalid input $choice"
            ask_about_nginx
            ;;
    esac
}

# OPEN GITLAB TO THE OUTSIDE WORLD
ask_about_nginx
service gitlab start

echo "Checking GitLab installation..."
run_as_git_user bundle exec rake gitlab:check RAILS_ENV=production

echo "GitLab install complete"
echo ""
echo "Visit $GITLAB_URL for your first GitLab login."
echo "The setup has created an admin account for you. You can use it to log in:"
echo "admin@local.host"
echo "5iveL!fe"