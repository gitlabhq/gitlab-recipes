# bitbucket2gitlab

Port your issues over from bitbucket.

> This script is kindly taken from <https://github.com/Inbot/bitbucket2gitlab>.
> Modified README for the gitlab-recipes repository.

### Instructions

**Note:** It is recommended to test this with a test project in GitLab that you
    can discard before running this against the real thing.

1. From bitbucket go to the project's settings and then select **Import & export**.
   Start the export and you should get a zip file with a json file inside.
1. Unzip it and place `db-1.0.json` in the same folder as the script.
1. Modify the global variables inside `bitbucket2gitlab.rb` to match your
   project settings.
1. Run `ruby ./bitbucket2gitlab.rb`.
1. Repeat steps 1-4 for all your other projects.

### Limitations

- It gets you the raw content (comments and issues) but things like milestones,
  assignments, create timestamps, etc. are lost.
- The order of the imported comments is probably wrong (should be sorted by timestamp).
- There is no duplication check, which is annoying if the script breaks mid import
  for whatever reason and you need to run it again.
- Attachments are not supported currently.
