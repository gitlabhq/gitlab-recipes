# CentOS related Nginx notes

If nginx installed through package manager, adjust sites in conf.d instead of sites-enabled.

Set user gitlab in group root for user in nginx.conf:

    #user              nginx;
    user              gitlab root;

Or:

    sudo /usr/sbin/usermod -a -G gitlab nginx
    sudo /bin/chmod g+rx /home/gitlab/
