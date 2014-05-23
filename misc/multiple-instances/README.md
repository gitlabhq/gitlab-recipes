```
Distribution      : Independent
GitLab version    : 6.0 - 6.7
Web Server        : apache
Init system       : sysvinit
Database          : Independent
Contributors      : @skarllot
```

## Overview

To run multiple instances into same computer, some changes are needed to GitLab
function properly. Each instance will run completely independent, no resource
sharing or redundancy will be supported.

Before you follow this guide you should know how install GitLab as single
instance. This guide focus only on changes needed to another instances run
properly, not into installation itself.

### Important Notes

These steps was tested into CentOS GNU/Linux, but should run into another
flavours with (almost) no differences.

## 1. System Users

Each instance must run into its own user. There's no way to gitlab-shell known
which instance you are calling.

Then, create a new user to a new GitLab instance.

## 2. GitLab Shell

The following changes are needed to `config.yml`

 - **user**: the new user created from previous step.
 - **gitlab_url**: instance-unique http(s) address.
 - **repos_path**: instance-unique repository directory.
 - **auth_file**: must be changed to match SSH user directory from the created user.
 - **redis:namespace**: instance-unique Redis namespace.

Example:

```yaml
# GitLab user. git by default
user: user2

# Url to gitlab instance. Used for api calls. Should end with a slash.
gitlab_url: "https://user2.example.com/"

http_settings:
#  user: someone
#  password: somepass
#  ca_file: /etc/ssl/cert.pem
#  ca_path: /etc/pki/tls/certs
  self_signed_cert: false

# Repositories path
# Give the canonicalized absolute pathname,
# REPOS_PATH MUST NOT CONTAIN ANY SYMLINK!!!
# Check twice that none of the components is a symlink, including "/home".
repos_path: "/home/user2/repositories"

# File used as authorized_keys for gitlab user
auth_file: "/home/user2/.ssh/authorized_keys"

# Redis settings used for pushing commit notices to gitlab
redis:
  bin: /usr/bin/redis-cli
  host: 127.0.0.1
  port: 6379
  # socket: /tmp/redis.socket # Only define this if you want to use sockets
  namespace: resque:gitlab:user2

(...)
```

## 3. Database

Each GitLab instance should handle its own database schema. It's recommended
that each instance have its own database user.

## 4. GitLab

You must do the following changes to `config/gitlab.yml`

 - **gitlab:host**: instance-unique FQDN.
 - **gitlab:user**: the user created at first step.
 - **satellites:path**: the path where satellites of new user will be created.
 - **gitlab_shell:path**: the path where instance's GitLab Shell was installed.
 - **gitlab_shell:repos_path**: the path where instance's Git repositories will be stored.
 - **gitlab_shell:hooks_path**: the path where GitLab Shell store its hooks.

Next, change the following to `config/unicorn.rb`

 - **working_directory**: the path where GitLab was installed.
 - **listen[socket]**: change to match instance's GitLab install.
 - **listen[TCP]**: instance-unique TCP port.
 - **pid**, **stderr_path** and **stdout_path**: change to match instance's GitLab install.

Next, you need to change `config/initializers/4_sidekiq.rb` to use the same
Redis namespace as configured at second step.

Example:

```ruby
# Custom Redis configuration
config_file = Rails.root.join('config', 'resque.yml')

resque_url = if File.exists?(config_file)
               YAML.load_file(config_file)[Rails.env]
             else
               "redis://localhost:6379"
             end

Sidekiq.configure_server do |config|
  config.redis = {
    url: resque_url,
    namespace: 'resque:gitlab:user2'
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: resque_url,
    namespace: 'resque:gitlab:user2'
  }
end
```

### Database

Next, you should ensure that `config/database.yml` is not sharing the same
database from others instances. Then create the database with `gitlab:setup`.

### Init Script

Each instance must have its own init script (eg: `/etc/init.d/gitlab-user2`).

Next, modify the init script as follows

 - **USER**: the name of the user created at first step.
 - **APP_PATH**: the path where GitLab was installed.
 - **ULOCK**: instance-unique path to Unicorn lock file.
 - **SLOCK**: instance-unique path to Sidekiq lock file.

### LogRotate

Each instance must have its own logrotate script (eg:
`/etc/logrotate.d/gitlab-user2`).

Next you must modify the paths from logrotate script to match where the logs are
written.

## 5. Web Server

### Apache

Each instance must have its own Apache configuration file (eg:
`gitlab-user2.conf`).

The following changes must be made to configuration file

 - **ServerName**: instance-unique FQDN.
 - **ProxyPassReverse** and **RewriteRule**: must change to the port where instance's Unicorn is listening.
 - **ErrorLog** and **CustomLog**: instance-unique path where the Apache logs will be written.

