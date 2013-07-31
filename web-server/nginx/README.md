# CentOS related Nginx notes

* If nginx is installed through the package manager, adjust sites in conf.d instead of sites-enabled.

* Replace the default `nginx` user with `gitlab` in group `root`.

  In `/etc/nginx/nginx.conf`:

      #user              nginx;
      user              gitlab root;
