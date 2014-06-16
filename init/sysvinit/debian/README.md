Alternative sysvinit file for puma. Tested on Debian/Ubuntu but this should work for all Debian based distros.
Make sure you have the `puma` gem installed and `puma.rb` in `/home/git/gitlab/config/`.

Get `gitlab-puma` in your `/etc/init.d/` directory:

    wget -O /etc/init.d/gitlab https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/sysvinit/debian/gitlab-puma

Then start the service with:

    service gitlab start
