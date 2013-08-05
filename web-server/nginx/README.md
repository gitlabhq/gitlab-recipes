# CentOS related Nginx notes

* If nginx is installed through the package manager, adjust sites in `/etc/nginx/conf.d/` instead of `/etc/nginx/sites-available/`.

* Replace the default `nginx` user with `git` and group `root` in `/etc/nginx/nginx.conf`:

      #user             nginx;
      user              git root;

  or add `nginx` user to `git` group.

      sudo usermod -a -G git nginx
      sudo chmod g+rx /home/git/
