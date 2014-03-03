# Move home directory from /home/git to /var/lib/git

### 0. Stop services

```bash
service gitlab stop
service nginx stop
```

### 1. Update passwd/group file

Update the `/etc/group` file, and change the gid of the group

```bash
git:x:500:
```
or you can run the following command

```bash
groupmod -g 500 git
```

Amend the `/etc/passwd` file to change the uid, gid and the home directory for git

```bash
git:x:500:500:GitLab,,,:/var/lib/git:/bin/bash
```
or you can run the following command

```bash
usermod -d /var/lib/git -g 500 -u 500 git
```

### 2. Copy the git folder

```bash
cp -r /home/git /var/lib/
```

### 3. Change permissions to use the new uid/gid

```bash
chown -R git:git /var/lib/git
```

### 4. Update Gitlab config files

Update `~git/gitlab/config/gitlab.yml`, using the following command

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/gitlab/config/gitlab.yml
```

You should see the following difference after running the command

```diff
--- gitlab.yml.example  2013-12-20 16:27:14.784403409 -0500
+++ gitlab.yml  2014-01-05 15:11:17.706013229 -0500
@@ -165,7 +166,7 @@
   # GitLab Satellites
   satellites:
     # Relative paths are relative to Rails.root (default: tmp/repo_satellites/)
-    path: /home/git/gitlab-satellites/
+    path: /var/lib/git/gitlab-satellites/
 
   ## Backup
@@ -174,11 +175,11 @@
 
   ## GitLab Shell settings
   gitlab_shell:
-    path: /home/git/gitlab-shell/
+    path: /var/lib/git/gitlab-shell/
 
     # REPOS_PATH MUST NOT BE A SYMLINK!!!
-    repos_path: /home/git/repositories/
-    hooks_path: /home/git/gitlab-shell/hooks/
+    repos_path: /var/lib/git/repositories/
+    hooks_path: /var/lib/git/gitlab-shell/hooks/
 
     # Git over HTTP
     upload_pack: true
```
Update `~git/gitlab/config/unicorb.rb`, using the following command

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/gitlab/config/unicorn.rb
```

You should see the following difference after running the command

```diff
--- unicorn.rb.example  2013-12-20 16:27:14.795402739 -0500
+++ unicorn.rb  2014-01-07 07:47:33.786389865 -0500
@@ -32,24 +32,24 @@
 
 # Help ensure your application will always spawn in the symlinked
 # "current" directory that Capistrano sets up.
-working_directory "/home/git/gitlab" # available in 0.94.0+
+working_directory "/var/lib/git/gitlab" # available in 0.94.0+
 
 # listen on both a Unix domain socket and a TCP port,
 # we use a shorter backlog for quicker failover when busy
-listen "/home/git/gitlab/tmp/sockets/gitlab.socket", :backlog => 64
+listen "/var/lib/git/gitlab/tmp/sockets/gitlab.socket", :backlog => 64
 listen "127.0.0.1:8080", :tcp_nopush => true
 
 # nuke workers after 30 seconds instead of 60 seconds (the default)
 timeout 30
 
 # feel free to point this anywhere accessible on the filesystem
-pid "/home/git/gitlab/tmp/pids/unicorn.pid"
+pid "/var/lib/git/gitlab/tmp/pids/unicorn.pid"
 
 # By default, the Unicorn logger will write to stderr.
 # Additionally, some applications/frameworks log to stderr or stdout,
 # so prevent them from going to /dev/null when daemonized here:
-stderr_path "/home/git/gitlab/log/unicorn.stderr.log"
-stdout_path "/home/git/gitlab/log/unicorn.stdout.log"
+stderr_path "/var/lib/git/gitlab/log/unicorn.stderr.log"
+stdout_path "/var/lib/git/gitlab/log/unicorn.stdout.log"
 
 # combine Ruby 2.0.0dev or REE with "preload_app true" for memory savings
 # http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
```

### 5. Update Gitlab shell config file

Update `~git/gitlab-shell/config.yml`, using the following command

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/gitlab-shell/config.yml
```

You should see the following difference after running the command

```diff
--- config.yml.old      2014-01-07 09:00:41.522352570 -0500
+++ config.yml  2014-01-05 15:12:59.695840545 -0500
@@ -15,10 +15,10 @@
 # Give the canonicalized absolute pathname,
 # REPOS_PATH MUST NOT CONTAIN ANY SYMLINK!!!
 # Check twice that none of the components is a symlink, including "/home".
-repos_path: "/home/git/repositories"
+repos_path: "/var/lib/git/repositories"
 
 # File used as authorized_keys for gitlab user
-auth_file: "/home/git/.ssh/authorized_keys"
+auth_file: "/var/lib/git/.ssh/authorized_keys"
 
 # Redis settings used for pushing commit notices to gitlab
 redis:
```

### 6. Update authorized_keys

Update the `/var/lib/git/.ssh/authorized_keys`, using the following command

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/.ssh/authorized_keys
```

### 7. Update nginx config file

Update `/etc/nginx/sites-enabled/gitlab`, using the following command

```bash
sed -i -e 's/\/home/\/var\/lib/g' /etc/nginx/sites-enabled/gitlab
```

### 8. Add/Update gitlab service and default files

If you haven't already, copy the service default file, then do so, and then update the file to point to the new home directory

```bash
cp ~git/gitlab/lib/support/init.d/gitlab.default.example /etc/default/gitlab
sed -i -e 's/\/home/\/var\/lib/g' /etc/default/gitlab
```

### 9. Update gitlab-shell hooks

The file `~git/gitlab-shell/support/rewrite-hooks.sh`, has the home directory hardcoded, so we need to update this file as well

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/gitlab-shell/support/rewrite-hooks.sh
```

Now we update all the hooks

```bash
cd ~git
sudo -u git -H gitlab-shell/support/rewrite-hooks.sh
```

### 10. Update deploy.sh

The file `~git/gitlab/lib/support/deploy/deploy.sh`, also has the home directory hardcoded, again update the file

```bash
sed -i -e 's/\/home/\/var\/lib/g' ~git/gitlab/lib/support/deploy/deploy.sh
```

### 11. Update logrotate files

```
sed -i -e 's/\/home/\/var\/lib/g' /etc/logrotate.d/gitlab
```

### 12. Restart application

```bash
sudo service gitlab restart
sudo service nginx restart
```

### 13. Check application status

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

### 14. Remove old home

Once you are happy that everything is now working in the new directory, you can remove the old `/home/git`

```bash
rm -rf /home/git
```
