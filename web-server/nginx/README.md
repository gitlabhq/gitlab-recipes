## CentOS related Nginx notes

### Different conf directories

If nginx is installed through the package manager, adjust sites in `/etc/nginx/conf.d/` 
instead of `/etc/nginx/sites-available/` or create those directories and tell `nginx`
to monitor them:

    sudo mkdir /etc/nginx/sites-{available,enabled}

Then edit `/etc/nginx/nginx.conf` and replace `include /etc/nginx/conf.d/*.conf;`
with `/etc/nginx/sites-enabled/*;`

### Give nginx access to git group

In order for GitLab to display properly you have to make either one of the changes
below. The first one is recommended.

Add `nginx` user to `git` group:

    sudo usermod -a -G git nginx
    sudo chmod g+rx /home/git/

or replace the default `nginx` user with `git` and group `root` in `/etc/nginx/nginx.conf`:

    #user             nginx;
    user              git root;
