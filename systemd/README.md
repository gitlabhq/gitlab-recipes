## GitLab startup services for systemd (CentOS, Fedora)

GitLab requires couple of services:
* Web server (apache, nginx, etc.)
* Redis server
* Mail server (postfix or other)
* GitLab Sidekiq service (`sidekiq.service`)


## Setup GitLab Sidekiq service
1. simply copy* `sidekiq.service` to `/etc/systemd/system/default.target.wants/` (or can to `multi-user.target.wants`)
2. reload systemd: `systemctl --system daemon-reload`
3. `systemctl start sidekiq` (for older systemd versions you would need `systemctl start sidekiq.service`)

`*` - if you've gitlab in other path than `/home/gitlab/gitlab` then change `sidekiq.service` accordinaly.


####Note
`/etc/systemd/system/` have a higher precedence over  `/lib/systemd/system`

