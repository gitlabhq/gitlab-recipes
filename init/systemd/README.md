## GitLab startup services for systemd (Archlinux, Fedora, etc)

GitLab requires a couple of services:
* Web server (apache, nginx, etc.)
* Redis server
* Mail server (postfix or other)
* GitLab Sidekiq service (`gitlab-sidekiq.service`)
* Unicorn service (`gitlab-unicorn.service`)


## Setup GitLab services

Copy files to `/etc/systemd/system/`:

```
su -
cd /etc/systemd/system/
wget -O gitlab-sidekiq.service https://raw.github.com/gitlabhq/gitlab-recipes/master/init/systemd/gitlab-sidekiq.service
wget -O gitlab-unicorn.service https://raw.github.com/gitlabhq/gitlab-recipes/master/init/systemd/gitlab-unicorn.service
wget -O gitlab.target https://raw.github.com/gitlabhq/gitlab-recipes/master/init/systemd/gitlab.target
```

Reload systemd:

    sudo systemctl --system daemon-reload

Start the services:

    sudo systemctl start gitlab-sidekiq gitlab-unicorn

Enable them to start at boot:

    sudo systemctl enable gitlab.target gitlab-sidekiq gitlab-unicorn

## Notes

* If you installed GitLab in other path than `/home/git/gitlab` change the service files accordingly.

* `/etc/systemd/system/` have a higher precedence over  `/lib/systemd/system`.

* For older systemd versions you need to append `service` after the service name. For example:

        sudo systemctl start gitlab-sidekiq.service
