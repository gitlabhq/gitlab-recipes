## Nginx config moved to official repository

You can find the nginx config in [GitLab official repository][gitlab] which can
be used for source installations.

## Omnibus configs

The configuration files in this directory are known to work  with GitLab 8.2
and newer versions.

For versions of GitLab 8.0 and 8.1, check the `8-1-stable` branch.

For versions of GitLab 8.2, check the `8-2-stable` branch.

---

GitLab 8.3 introduces major changes in the NGINX configuration. Because all
HTTP requests now pass through gitlab-workhorse, a lot of directives need to be
removed from NGINX. During future upgrades there should be much less changes in
the NGINX configuration because of this.

[Omnibus packages][] use their own bundled nginx server. If you want to use your
own external Nginx server, follow the first 3 steps to
[configure GitLab][omnibusnginxext] and then download the appropriate config
file (ssl or non-ssl) from this directory.

After placing the configs in their appropriate location
(read [Different conf directories](#different-conf-directories)), make sure to
restart Nginx.

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

[gitlab]: https://gitlab.com/gitlab-org/gitlab-ce/tree/master/lib/support/nginx "Nginx config for GitLab"
[Omnibus packages]: https://about.gitlab.com/downloads/
[omnibusnginxext]: http://doc.gitlab.com/omnibus/settings/nginx.html#using-a-non-bundled-web-server
