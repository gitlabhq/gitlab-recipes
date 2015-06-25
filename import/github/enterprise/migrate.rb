#!/opt/gitlab/embedded/bin/ruby
require './jk'
require 'git'

# Migration script for Github -> Gitlab
def do_migration
  my_domain = "your.domain"
  gh_ssh_url_base="git@github.your.domain"
  gl_ssh_url_base="git@gitlab.your.domain"
  tmp_git_dir="/git-data/tmp"
  hook_url = "https://your.domain/jira/gitlab_hook"

  ldap_github_group = "GithubUsersGroup"

  ad_username = "user@your.domain"
  ad_password = "xxxxxxxxxxxxxxxxxxxxxx"
  ad_base = "dc=your,dc=domain"
  ad_host = "your.ad.host"

  gh_login = "github_user",
  gh_password = "xxxxxxxxxxxxxxxxxxxxxx"
  gh_api_endpoint = "https://github.your.domain/api/v3/"
  gh_web_endpoint = "https://github.your.domain/"

  gl_api_endpoint = 'https://gitlab.your.domain/api/v3'
  gl_admin_token = 'xxxxxxxxxxxxxxxxxxxx'

  gh = Jk::Githubz.new(gh_login, gh_password, gh_api_endpoint, gh_web_endpoint)
  gl = Jk::Gitlabz.new(gl_api_endpoint, gl_admin_token)

  org_teams_hash,teams_members_hash = gh.get_org_teams
  ad = Jk::Ad.new(ad_host, ad_username, ad_password, ad_base)
  org_teams_hash,teams_members_hash,cn_user_info_hash =
    ad.get_membership_hashes(org_teams_hash, teams_members_hash, ldap_github_group)

  # create users from our github group in ldap
  cn_user_info_hash.each { |cn, user_info_hash|
    #"CN=Some Body,OU=Users,OU=ad,DC=testers,DC=com" => {
    #    :dn=>"CN=Some Body,OU=Users,OU=ad,DC=testers,DC=com",
    #    :title=>"Senior Wizard",
    #    :displayname=>"Some Body",
    #    :memberof=>"CN=.All Users,OU=Distribution Lists,OU=Users,DC=testers,DC=com",
    #    :samaccountname=>"SBody"
    #    }
    puts("Adding #{user_info_hash[:displayname]}")
    gl.add_user(
      "#{user_info_hash[:samaccountname].downcase}@#{my_domain}",
      "2689009d91eb2837804a9ca1c598c461", # password doesn't matter for ldap
      user_info_hash[:samaccountname].downcase,
      user_info_hash[:displayname],
      cn,
      "#{user_info_hash[:title]}"
    )
  }

  # get user keys from github and store them in gitlab per user
  user_key_hash = gh.get_user_key_hash
  user_key_hash.each { |username, keys|
    cnt = 1
    keys.each { |key|
      puts("adding #{username} Key import #{cnt} #{key}")
      gl.add_key_for_user(username, "Key import #{cnt}", key)
      cnt += 1
    }
  }

  # create groups (org) and projects (repos)
  gh_org_repos = gh.get_org_repo_hash
  gh_org_repos.each { |gh_org_name, gh_repo_name_arr|
    gl_org_id = gl.create_or_get_group_id(gh_org_name)
    gh_repo_name_arr.each { |gh_repo_name|
      gl_proj_id = gl.create_and_get_project_id(gh_repo_name, gh_org_name)
    }
  }

  # take github org teams and apply the perms to gitlab
  # gitlab has no team concept so we'll give either owner or dev
  # privs to each user based on their github privs.
  org_teams_hash.each { |gh_org_name, gh_teams|
    gh_teams.each { |gh_team|
      teams_members_hash[gh_team.to_sym].each { |user_cn|
        gl_org_id = gl.create_or_get_group_id(gh_org_name)
        user_hash = cn_user_info_hash[user_cn]
        if user_hash
          user_id = user_hash[:samaccountname].downcase
          if (gh_team =~ /Owners$/)
            puts("Adding OWNER user #{user_id} to org #{gh_org_name} with org id #{gl_org_id} for team #{gh_team}")
            perm = 50
          else
            puts("Adding user #{user_id} to org #{gh_org_name} with org id #{gl_org_id} for team #{gh_team}")
            perm = 30
          end
          if (gl.get_users_id_hash()[user_id])
            gl.add_dev_to_group(gl.get_users_id_hash()[user_id], gl_org_id, perm)
          else
            puts("Can't find #{user_id}")
          end
        end
      }
    }
  }

  # time to clone git repos
  gh_org_repos = gh.get_org_repo_hash

  gh_org_repos.each { |gh_org_name, gh_repo_name_arr|
    gh_repo_name_arr.each { |gh_repo_name|
      repo_name = gh_repo_name
      gh_ssh_url = "#{gh_ssh_url_base}:#{gh_org_name}/#{gh_repo_name}.git"
      local_repo_name = "#{repo_name}.git"
      puts("clone #{gh_ssh_url} to #{gh_org_name}/#{local_repo_name}")

      FileUtils.mkdir_p("#{tmp_git_dir}/#{gh_org_name}")
      if File.directory?("#{tmp_git_dir}/#{gh_org_name}/#{local_repo_name}")
        git_repo = Git.bare("#{tmp_git_dir}/#{gh_org_name}/#{local_repo_name}")
        git_repo.fetch
      else
        git_repo = Git.clone(gh_ssh_url, "#{local_repo_name}", :path => "#{tmp_git_dir}/#{gh_org_name}", :bare => 1)
        git_repo.add_remote("gitlab", "#{gl_ssh_url_base}:#{gh_org_name}/#{local_repo_name}")
      end
      git_repo.push('gitlab', '--mirror')
    }
  }

  # merge github pull requests to gitlab issues
  gl.get_project_name_id_hash().each { |repo, proj_id|
    gh.get_pull_requests_comments_for_repo(repo).each { |pr|
      commits_str = "| User | SHA | Date | Message |\n"
      commits_str += "| ---- | ---- | ---- | ---- |\n"
      pr[:commits].each { |c|
        commits_str += "|@#{c[:username]}|#{repo}@#{c[:sha]}|#{c[:date]}|#{c[:message].split("\n").first}|\n"
      }

      comments_str = ""
      pr[:comments].each { |c|
        body = "#{c[:body]}"
        body = body.gsub(/^/, "> ")
        comments_str += "#### Comment by @#{c[:username]} on #{c[:date]}\n"
        comments_str += "#{body}\n\n"
      }
      comments_str = "(no comments)" if comments_str.length == 0

      output_str = "### Pull request #{pr[:number]} migrated from Github

#{pr[:body]}

#### Commits
#{commits_str}

#{comments_str}

  "
      puts("Creating issue #{pr[:number]} for #{repo}")
      gl.create_issue(repo, pr[:title], output_str)
    }
  }

  # gitlab marks master branches protected by default, we'll unprotect so our
  # devs can push directly if they please, not ideal but some teams rely on it
  gl.get_project_name_id_hash().each { |repo, proj_id|
    gl.unprotect_branches_for_project(proj_id)
  }

  # Added our custom push hook url to each repo
  gl.get_project_name_id_hash().each { |repo, proj_id|
    gl.add_hook_to_proj(proj_id, hook_url)
  }
end

#do_migration
