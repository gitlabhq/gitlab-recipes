# Caddy

This is an example configuration of how to use GitLab with [caddy](https://caddyserver.com/).

## GitLab

### Updating GitLab Configuration

Open `/etc/gitlab/gitlab.rb` using your favourite text editor and update the following values.

* Change `external_url` to the https protocol
* Change `gitlab_workhorse['listen_network']` from `"unix"` to `"tcp"`
* Change `gitlab_workhorse['listen_addr']` from `"/var/opt/gitlab/gitlab-workhorse/socket"` to `"127.0.0.1:8181"`
* Add whatever user caddy runs under to `web_server['external_users']` unless root
* Change `nginx['enable'] = "true"` to `nginx['enable'] = "false"`
* Save and exit the configuration file and run `gitlab-ctl reconfigure` to update gitlabs configuration

### Updating the Caddyfile

Simply change gitlab.example.com to point to your FQDN.

## GitLab Pages

### Updating GitLab Configuration

Change `https://example.io` to point to your pages domain:

```ruby
pages_external_url "https://example.io"

gitlab_pages['enable'] = true
gitlab_pages['listen_proxy'] = "127.0.0.1:8090"
gitlab_pages['redirect_http'] = true
gitlab_pages['use_http2'] = true
gitlab_pages['metrics_address'] = ":9235"
```

### Updating the Caddyfile

Simply change `*.example.io` to point to your pages domain (must be different from you GitLab domain).
