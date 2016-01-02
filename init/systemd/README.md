## GitLab startup services for systemd (Archlinux, Fedora, etc)

GitLab requires a couple of services:
* Web server (apache, nginx, etc.)
* Redis server
* Mail server (postfix or other)
* GitLab Sidekiq service (`gitlab-sidekiq.service`)
* Unicorn service (`gitlab-unicorn.service`)
* Gitlab Workhorse server for slow HTTP requests (`gitlab-workhorse.service`)


## Setup GitLab services

Copy files to `/etc/systemd/system/`:

```
sudo su
cd /etc/systemd/system/
wget -O gitlab-sidekiq.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-sidekiq.service
wget -O gitlab-unicorn.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-unicorn.service
wget -O gitlab-workhorse.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-workhorse.service
wget -O gitlab-mailroom.service https://gitlab.com/gitlab-org/gitlab-recipes/raw/master/init/systemd/gitlab-mailroom.service
```

Reload systemd:

    sudo systemctl daemon-reload

Start the services:

    sudo systemctl start gitlab-sidekiq.service gitlab-unicorn.service gitlab-workhorse.service gitlab-mailroom.service

Enable them to start at boot:

    sudo systemctl enable gitlab-sidekiq.service gitlab-unicorn.service gitlab-workhorse.service gitlab-mailroom.service

## Notes

* If you installed GitLab in other path than `/home/git/gitlab` change the service files accordingly.

* `/etc/systemd/system/` have a higher precedence over  `/usr/lib/systemd/system`.
