#!/opt/gitlab/embedded/bin/ruby
require './jk'

# repos are created less frequently than users, schedule this to run 
# accordingly. This will make a hit for every single repo to check for the
# existence of our hook, so it takes a minute to run.
def update_hooks
  hook_url = "https://your.domain/jira/gitlab_hook"

  gl_api_endpoint = 'https://gitlab.your.domain/api/v3'
  gl_admin_token = 'xxxxxxxxxxxxxxxxxxxx'

  gl = Jk::Gitlabz.new(gl_api_endpoint, gl_admin_token)

  # Added our custom push hook url to each repo
  gl.get_project_name_id_hash().each { |repo, proj_id|
    gl.add_hook_to_proj(proj_id, hook_url)
  }
end

update_hooks
