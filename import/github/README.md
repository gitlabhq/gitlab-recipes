import_all.rb is a ruby script that can import repositories from GitHub to GitLab.

## Simple usage:
```bash
ruby import_all.rb -u <github login> -p <github password> \ 
-s <github space to import projects from> -t <gitlab secret key> \
--gitlab-api http://<my.gitlab.host>/api/v3
```
This command will import all public projects from specified space. Take in mind, that you should specify valid GitHub user login and password (2-factor authentication is not supported). Also, script uses directory /tmp/clones, it should be **created** and **empty**.

## CLI options
* **-u, --user USER** - user to connect to *GitHub* with. Valid *GitHub* user login.
* **-p, --pw PASSWORD** - password for user to connect to *GitHub* with. Valid *GitHub* user password.
* **--api API** - API endpoint for *GitHub*. Default is "https://api.github.com". Change it to import from the *GitHub* Enterprise.
* **--web** - Web endpoint for *GitHub*. Default is "https://github.com/". Change it to import from the *GitHub* Enterprise.
* **--gitlab-api API** - API endpoint for *GitLab*. Set it to API endpoint of the destination *GitLab* instance.
* **-t, --gitlab-token TOKEN** - Private token for *GitLab*. Set it to the token from your *GitLab* account (http://my.gitlab.host/profile/account).
* **--ssh** - Use ssh for *GitHub*. By default, script uses **https** protocol to access *GitHub*. Use this option to change the protocol to the **ssh**.
* **-s, --space SPACE** - The space to import repositories from (User or Organization). If **--group** is not set, **SPACE** will also be used to determine destination projects **group** in *GitLab*. If **SPACE** is not set, the default space of the authenticated user will be used.
* **-g, --group GROUP** - The *GitLab* group to import projects to. Determines destination projects **group** in *GitLab*.
* **--private** - Import only private *GitHub* repositories (enables ssh). By default, script will try to import only public projects from specified space. Use this option to import only private projects of authenticated user (automatically enables **ssh** protocol, ignores **SPACE**).
* **--all** - Import both private and public *GitHub* repositories (enables ssh). By default, script will try to import only public projects from specified space. Use this option to import both public and private projects of authenticated user (automatically enables **ssh** protocol, ignores **SPACE**).
* **--repository REPOSITORY** -- Import only specified repository. By default, script will try to import all available repositories from selected **SPACE**. This option allows to import only one specified repository.
* **--[no-]issues** - [do not] import issues. Use this switch to enable or disable import of issues. Enabled by default.
* **--[no-]milestones** - [do not] import milestones. Use this switch to enable or disable import of milestones. Enabled by default.
* **-h, --help** - Display help.

## Examples
1. This example will import all private repositories of user1 from user1 **SPACE** from *GitHub* (https://github.com/user1/*) to user1 project group in *GitLab* (http://gitlab.example.com/user1/*).
```bash
rm -rf /tmp/clones/ && # remove /tmp/clones/ directory
mkdir /tmp/clones/ && # and recreate it
ruby import_all.rb -u user1 -p password_of_user1 -s user1 --private \ 
--gitlab-api http://gitlab.example.com/api/v3 -t some_private_token_from_gitalb 
```

2. This example will import all public repositories from gitlabhq **SPACE** from *GitHub* (https://github.com/gitlabhq/*) to group1 project group in *GitLab* (http://gitlab.example.com/group1/*) without issues.
```bash
rm -rf /tmp/clones/ &&
mkdir /tmp/clones/ &&
ruby import_all.rb -u user1 -p password_of_user1 --group group1 \
-s gitlabhq --gitlab-api http://gitlab.example.com/api/v3 --no-issues \
-t some_private_token_from_gitalb 
```

3. This example will import repository gitlabhq/gitlab-ci from *GitHub* (https://github.com/gitlabhq/gitlab-ci) to group2 project group in *GitLab* (http://gitlab.example.com/group2/gitlab-ci) with issues.
```bash
rm -rf /tmp/clones/ &&
mkdir /tmp/clones/ &&
ruby import_all.rb -u user1 -p password_of_user1 \ 
--gitlab-api http://gitlab.example.com/api/v3 --group group2 \
-t some_private_token_from_gitalb  --repository gitlabhq/gitlab-ci
```
