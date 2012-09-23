gitlab-recipes
==============

GitLab recipes for setup on different platforms, update etc...


### Linux Containers Support

For setup within 'lxc' (Linux containers) use the following procedure:

    lxc-create -n debian -t debian
    lxc-start -n debian -f /etc/lxc/debian/config
    cd debian/rootfs
    wget https://raw.github.com/globalcitizen/gitlab-recipes/master/install/debian_ubuntu.sh
    cd ..
    lxc-start -n debian -f ./config

    # after container boots, login as root:root then continue
    cd /
    sh debian_ubuntu.sh
  

### Every file should have section with maintainer name & gitlab version:

    # GITLAB
    # Maintainer: @randx
    # App Version: 2.9
