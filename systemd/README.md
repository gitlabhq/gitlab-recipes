##GitLab startup services for systemd (CentOS, Fedora)

GitLab requires couple of services:
 * Web server (apache, nginx, etc.)
 * Redis server
 * Mail server (postfix or other)
 * GitLab Sidekiq service (`sidekiq.service`)

## Setup GitLab Sidekiq service

1. simply copy `sidekiq.service` to `/etc/systemd/system/default.target.wants/` (or can to `multi-user.target.wants`)
(Note: `/etc/systemd/system/` have a higher precedence than  `/lib/systemd/system`)
2. reload systemd: `systemctl --system daemon-reload`
3. `systemctl start sidekiq` (for older systemd versions you would need `systemctl start sidekiq.service`)


