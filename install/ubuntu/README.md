One script installer for clean ubuntu 12.04 x64
==============

Made for GitLab v6.1

### ABOUT

This script performs a complete installation of Gitlab for ubuntu server 12.04 LTS x64:
* packages update
* git, postfix etc
* ruby setup
* git user
* gitlab-shell fork


### Notes

__!IMPORTANT run as root or sudo without prompting password cause script ignore any input.__


### USAGE

#### 1. Run script (replace gitlab.example.com with your domain or ip address)

    curl https://raw.github.com/gitlabhq/gitlab-recipes/master/install/ubuntu/ubuntu_server_1204.sh | sudo domain_var=gitlab.example.com sh

#### 2. Reboot machine
