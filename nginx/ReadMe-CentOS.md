# CentOS related Nginx notes

If nginx installed through package manager, adjust sites in conf.d instead of sites-enabled.

Set user gitlab in group root for user in nginx.conf:

    #user              nginx;
    user              gitlab root;

