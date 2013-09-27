# Interactive Install Script for GitLab 6.1 on Ubuntu 12.04/12.10

#### by doublerebel

https://github.com/doublerebel/gitlab-recipes/blob/master/install/ubuntu/ubuntu_server_1204.sh

### Usage (run as root):

    # ./ubuntu_server_1204.sh [--url <yourgitlabdomain.com>] [--db <mysql|postgres>] [--gitlab <version>] [--shell <version>]

Requires `--url` parameter.  Default database is `mysql`.

Script provides information about current progress.  If installation fails, script can be re-run safely.

#### Example

    $ git clone https://github.com/doublerebel/gitlab-recipes.git
    $ cd gitlab-recipes/install/ubuntu
    $ sudo ./ubuntu_server_1204.sh --url your.gitlabdomain.com

### More info

  * Prompts to install Python 2 if not found.

  * Prompts to install Ruby 2.0 from [Brightbox PPA](https://launchpad.net/~brightbox/+archive/ruby-ng-experimental) if not found.

  * Prompts for MySQL root password if MySQL is already installed.

  * Prompts to install Nginx and site config.

  * GitLab and dependency versions are factored out for easy update upon release of new versions.
