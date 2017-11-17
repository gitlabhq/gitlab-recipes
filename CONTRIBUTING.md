## Developer Certificate of Origin + License

By contributing to GitLab B.V., You accept and agree to the following terms and
conditions for Your present and future Contributions submitted to GitLab B.V.
Except for the license granted herein to GitLab B.V. and recipients of software
distributed by GitLab B.V., You reserve all right, title, and interest in and to
Your Contributions. All Contributions are subject to the following DCO + License
terms.

[DCO + License](https://gitlab.com/gitlab-org/dco/blob/master/README.md)

_This notice should stay as the first item in the CONTRIBUTING.md file._

# Contribute to GitLab recipes

This guide details how to use issues and pull requests to improve GitLab recipes.

Please stick as close as possible to the guidelines. That way we ensure quality guides
and easy to merge requests.

Your Pull Request will be reviewed by one of our devs/volunteers and you will be
asked to reformat it if needed. We don't bite and we will try to be as flexible
as possible, so don't get intimidated by the extent of the guidelines :)

For better maintainance and clarity, some naming guidelines should be followed.
See details in each section below.

## License

MIT, see [LICENSE](LICENSE).

## Merge Request title

Try to be as more descriptive as you can in your Merge Request title.

Particularly if you are submitting a new script or guide, include in the title,
information about GitLab version, OS tested on and any other relevant info.

For example some good titles would be:

* [Installation script] GitLab 6.x - Ubuntu 12.04 - Apache
* [Guide] GitLab 6.1 - FreeBSD - postgres, rvm

## Guides

Each installation guide has its own namespace and it should be provided in a
`README` file so that it renders first when viewing the repository. Submit a new
one in `install/platform/README.md` (it doesn't have to be strictly in markdown though).

## Scripts

Installation scripts reside in `install/platform/scripts/`, so if you have one,
submit it there. They should named after the following scheme: `platform-platform_version`.

Example: `ubuntu-server-12.04.sh`

You are strongly encouraged to also provide a `README` file that describes
how to use the script. You may have included all the needed info in the script
itself (recommended), so you could simply write something between the lines:

  > This script installs GitLab 6.0 on Archlinux. Run it with `./archlinux.sh your_domain_name`
  >
  > For more info and variables you can change, read the comments in the script.


### Scripts doing similar things

There is a strong possibility that your script will do similar things to what a
script already in this repo do. In that case, please work on the existing script
and enhance it with your changes. No need to duplicate things.

## What information to put on your guide/script etc (mandatory)

If you have an installation guide to provide, fill in the template and place it on top
of it or include it in your installation script (commented), again on top. Try to
include as many items of this template as you can.

### Template

```
Distribution      : 
GitLab version    : 
Web Server        : 
Init system       : 
Database          : 
Contributors      : 
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
| Contributors     | Your github username (recommended in order to track you and give credits) or your real name or both. Example of the latter: **thedude (Jeffrey Lebowski)** |
| Additional Notes | Anything else you want to add. Any deviations form the official guide can be reported here. Eg. using rvm for ruby install, storing in different locations, etc.|


### Example

```
Distribution      : Fedora 19
GitLab version    : 5.4
Web Server        : apache with mod_passenger
Init system       : systemd
Database          : mariadb
Contributors      : thedude
Additional Notes  : the script uses rvm to install ruby
```
