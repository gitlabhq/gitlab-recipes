gitlab-recipes
==============

Unofficial guides for using GitLab with different software (operating systems, webservers, etc.)
provided by the community, for systems other than the officially supported (Debian/Ubuntu).

Bare in mind that this repository is co-maintained by volunteers/contributors like you.

# Contributing

## Naming guidelines

For better maintainance and clarity, some naming guidelines should be followed.

* Installation guides should be provided in README files so that they render first when viewing the repository.

* Installation scripts reside in a `scripts/` directory inside every platform folder.

### Scripts

There are scripts doing similar things

? Scripts should be named after the following scheme: platform-platform_version 
Example: `ubuntu-server-12.04.sh`

## Install information

If you have an installation guide to provide, fill in the template and place it on top
of your guide or include it in your installation script (commented), again on top.

### Template

```
Distribution      : 
GitLab version    : 
Web Server        : 
Init system       : 
Database          : 
Contributor       : 
Additional Notes  : 
```

### Explanation

| Label            | Explanation |
| ---------------- | ------------------------- |
| Distribution     | The official name and version of the platform/distribution, case sensitive.  |
| GitLab version   | GitLab version on which the guide/script was tested.    |
| Web Server       | The web server used to serve GitLab. May be two-fold, eg. apache with mod_passenger.  |
| Init system      | (Optional but recommended) The init system used by the platform if any. Examples: `sysvinit`, `systemd`, `upstart`, `openrc`, etc |
| Database         | The database used for installation. Examples: `mysql`, `postrgres`, `mariadb`.
| Contributor      | Your github username (recommended in order to track you and give credits) or your real name or both. Example of the latter: **thedude (Jeffrey Lebowski)** |
| Additional Notes | Anything else you want to add. Any deviations form the official guide can be reported here. Eg. using rvm for ruby install, storing in different locations, etc.|


### Example

```
Distribution      : Fedora 19
GitLab version    : 5.4
Web Server        : apache with mod_passenger 
Init system       : systemd
Database          : mariadb
Contributor       : thedude
Additional Notes  : the script uses rvm to install ruby
```

### Accepting Pull Requests

Please stick as close as possible to the guidelines. That way we ensure quality guides
and easy to merge requests.

Your Pull Request will be reviewed by one of our volunteers and you will be
asked to reformat it if needed. We don't bite and we will try to be as flexible
as possible, so don't get intimidated by the extent of the quidelines :)

## Notes

* We try to test everything before accepting PRs, in a clean, newly installed platform.
* You should read a script and understand what it does prior to running it.
* If something goes wrong during installation and you think the guide/script needs fixing, file a bug report or a Pull Request.
