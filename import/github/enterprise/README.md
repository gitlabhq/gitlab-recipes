# Github Enterprise Migration and Gitlab Active Directory Sync Example

This directory contains example code that was used to migrate an installation of Github Enterprise to Gitlab. It also has a script created to periodically sync LDAP/Active Directory users with Gitlab and assign permissions based on group membership. Finally a simple script to add a custom hook to all group repositories is included.

All code relies solely on the Github and Gitlab APIs for interaction (octokit, gitlab, git, and net/ldap gems). All configuration is done in the top level scripts (migrate.rb, update_gitlab.rb, and update_hooks.rb). All LDAP, Github, and Gitlab specific code is fairly generic and decoupled in classes located in corresponding files under ./jk

The Github migration should be run as a user that has admin access to all organizations and repositories you wish to migrate. The Gitlab code should also run as an admin user.

Of course this code will likely require heavy modification to suite individual needs but should serve as a decent example.
