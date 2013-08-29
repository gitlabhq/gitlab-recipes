Alternative configuration file for the `puma` application server. Copy it under `/home/git/gitlab/config/`.

## How to replace unicorn with puma

The easiest solution is to create a separate branch from the latest stable release
and work from there. Then, with every release we can merge the stable branch into ours.
Replace `latest-stable` with the latest stable branch.

```
su
service gitlab stop
su - git
cd gitlab/
git checkout latest-stable
git checkout -b puma
sed -i 's/unicorn/puma/' Gemfile

# For mysql
bundle install --without development test postgres --path vendor/bundle --no-deployment

# For postgres
bundle install --without development test mysql --path vendor/bundle --no-deployment
```

### Update GitLab version

When a new release is out all you have to do is merge it in puma branch.

```
# As git user

cd /home/git/gitlab/
git checkout master
git fetch
git checkout puma
git merge latest-stable
```

Then follow the official update instructions about migrations and the bundle install command.
