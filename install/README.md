## Naming guidelines

- consists? >= 2 files:

archlinux-gitlab

## General information

If you have an installation guide to provide, fill in the template and place it on top
of your guide or include it in your installation script (commented), again on top.

### Template

```
Distribution      : 
GitLab version    : 
Web Server        : 
Init system       :
Maintainer        : 
Additional Notes  :
```

### Explanation

| Label            | Explanation |
| ---------------- | ------------------------- |
| Distribution     | The official name and version of the platform/distribution, case sensitive.  |
| GitLab version   | GitLab version on which the guide/script was tested.    |
| Web Server       | The web server used to serve GitLab. May be two-fold, eg. apache with mod_passenger.  |
| Init system      | (Optional but recommended) The init system used by the platform if any. Examples: sysvinit, systemd, upstart, openrc, etc |
| Maintainer       | Your github username (recommended in order to track you and give credits) or your real name or both. Example of the latter: thedude (Jeffrey Lebowski) |
| Additional Notes | Anything else you want to add. Any deviations form the official guide can be reported here. Eg. using different user than `git`, storing in different locations, etc.|


### Example

```
Distribution      : Fedora 19
GitLab version    : 5.4
Web Server        : apache with mod_passenger 
Maintainer        : thedude
Additional Notes  : the script installs `postgres` instead of `mysql` and user is `gitlab` instead of `git`
```
