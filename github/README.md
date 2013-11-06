Migrate your repositories from github to gitlab
=======================================


1. Edit migrate.sh for your credentials
2. Add your ssh key to ssh-agen if you have an encrypted key
3. run ./migrate.sh

If you want to migrate only private repos from github add 
"type=private" to github url.

Unfortunaty, gitlab API doens't support namespaces yet, so all
created repositories are prefixed for security

