### 1. Update Nginx  config
Added the SSL section and a rewrite of port 80 to 443 in the Nginx configuration
```bash
nano /etc/nginx/sites-enabled/gitlab
```
```bash
server {
  listen 80;

  server_name   source.jcid.nl;
  rewrite       ^ https://$server_name$request_uri? permanent;
}

server {
  listen 443;
  server_name source.jcid.nl;
  root /home/git/gitlab/public;

  # SSL
  # ============================================================================
  ssl                   on;
  ssl_certificate       /etc/nginx/ssl/server.crt;
  ssl_certificate_key   /etc/nginx/ssl/server.key;
  ssl_protocols         SSLv3 TLSv1;

  #Disables all weak ciphers
  ssl_ciphers ALL:!aNULL:!ADH:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM;

  # Logs
  # ============================================================================

  access_log  /var/log/nginx/gitlab_access.log;
  error_log   /var/log/nginx/gitlab_error.log;

  location / {
    # serve static files from defined root folder;.
    # @gitlab is a named location for the upstream fallback, see below
    try_files $uri $uri/index.html $uri.html @gitlab;
  }

  # if a file, which is not found in the root folder is requested,
  # then the proxy pass the request to the upsteam (gitlab unicorn)
  location @gitlab {
    proxy_read_timeout 300; # https://github.com/gitlabhq/gitlabhq/issues/694
    proxy_connect_timeout 300; # https://github.com/gitlabhq/gitlabhq/issues/694
    proxy_redirect     off;

    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Host              $http_host;
    proxy_set_header   X-Real-IP         $remote_addr;

    proxy_pass http://gitlab;
  }
}
```

### 2. Place the SSL certificates
Create the folder for the SSL certificates and place the SSL certificates & the SSL certificates key here. In our situation, we combine the SSL Certificate with the CA Root Certificate.
```bash
mkdir /etc/nginx/ssl/ -p
cp /home/source.jcid.nl.cert /etc/nginx/ssl/server.crt
cp /home/source.jcid.nl.key /etc/nginx/ssl/server.key
```

### 3. Update Gitlab config files
Set the Gitlab https settings to true
```bash
nano /home/git/gitlab/config/gitlab.yml
```
```bash
  ## GitLab settings
  gitlab:
    ## Web server settings
    host: source.jcid.nl
    port: 80
    https: true
```

### 4. Update Gitlab shell config files
Set the Gitlab shell base url
```bash
nano /home/git/gitlab-shell/config.yml
```
```bash
# Url to gitlab instance. Used for api calls. Should be ends with slash.
gitlab_url: "https://source.jcid.nl/"
```

### 5. Restart application
```bash
sudo service gitlab restart
sudo service nginx restart
```

### 6. Check application status

Check if GitLab and its environment are configured correctly:

    sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

To make sure you didn't miss anything run a more thorough check with:

    sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

If all items are green, then the SSL certificate successfully implemented
