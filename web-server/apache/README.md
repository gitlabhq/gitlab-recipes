## CentOS notes

In CentOS the apache logs are under `/var/log/httpd` so you have to either replace
`apache` with `httpd` in `gitlab.conf` or create the `/var/log/apache2` directory.

## Puma or unicorn

### unicorn

Make sure that `/home/git/gitlab/config/unicorn.rb` exists
The default server is unicorn, so `gitlab.conf` is configured to listen on port `8080`.

### puma

Info taken from [PR #87](https://github.com/gitlabhq/gitlab-recipes/pull/87).

As apache's mod_proxy [doesn't support][sock] sockets, we have to configure the
proxy URL to use tcp instead of unix sockets. First make sure that `/home/git/gitlab/config/puma.rb` exists.
Then you have to make 2 changes:

1. In `gitlab.conf` replace `http://127.0.0.1:8080/ ` with `http://0.0.0.0:9292/`
2. Edit `puma.rb`: comment out `bind 'tcp://0.0.0.0:9292'` and comment `bind "unix://#{application_path}/tmp/sockets/gitlab.socket"`


[sock]: http://httpd.apache.org/docs/2.2/mod/mod_proxy.html
