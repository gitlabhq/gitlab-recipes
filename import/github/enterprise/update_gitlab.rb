#!/opt/gitlab/embedded/bin/ruby
require './jk'

# This script is scheduled via cron to perdiodically update perms
# perms are currently never revoked, only granted.
def update_perms

  ldap_github_group = "GithubUsersGroup"

  # The below names corespond to ldap/active directory groups
  # that are used to apply permissions to orgs/gitlab groups
  # each group key will point to an array of user CNs once populated.
  teams_members_hash = {
    :"Group1" => [],
    :"Group2" => [],
    :"Group3" => [],
    :"Group4" => [],
    :"Group5" => [],
    :"Group6" => [],
    :"Group7" => [],
    :"Group8" => [],
    :"GithubUsersGroup" => [],
  }

  # list of gitlab groups (orgs) and the LDAP groups that should have
  # permissions apllied
  org_teams_hash = {
    :org1=>["Group4", "Group8"],
    :org2=>["Group5", "Group6", "Group7"],
    :org3=>["Group1", "Group2", "Group3", "Group8"],
    :org4=>["Group3", "Group8"],
    :org5=>["Group3", "Group8"],
    :org6=>["GithubUsersGroup"],
    :org7=>["Group1", "Group3", "Group8"],
    :org8=>["Group2", "Group6", "Group7"],
    :org9=>["GithubUsersGroup"],
    :org10=>["Group1", "Group3"],
    :org11=>["Group1", "Group3", "Group8"],
    :org12=>[],
    :org13=>["Group1"]
  }

  my_domain = "your.domain"

  ad_username = "user@your.domain"
  ad_password = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
  ad_base = "dc=your,dc=domain"
  ad_host = "your.ad.host"

  gl_api_endpoint = 'https://gitlab.your.domain/api/v3'
  gl_admin_token = 'xxxxxxxxxxxxxxxxxxxx'

  gl = Jk::Gitlabz.new(gl_api_endpoint, gl_admin_token)
  ad = Jk::Ad.new(ad_host, ad_username, ad_password, ad_base)

  org_teams_hash, teams_members_hash, cn_user_info_hash =
    ad.get_membership_hashes(org_teams_hash, teams_members_hash, ldap_github_group)

  need_to_update = false

  cn_user_info_hash.each { |user_cn, user_info|
    if ! gl.get_users_cn_hash()[user_cn]
      need_to_update = true
      puts("Adding #{user_cn}")
      gl.add_user(
        "#{user_info[:samaccountname].downcase}@#{my_domain}",
        "2689009d91eb2837804a9ca1c598c461", # password doesn't matter for ldap
        user_info[:samaccountname].downcase,
        user_info[:displayname],
        user_cn,
        "#{user_info[:title]}"
      )
    end
  }

  gl.get_users_cn_hash(need_to_update)

  org_teams_hash.each { |gh_org_name, gh_teams|
    gh_teams.each { |gh_team|
      teams_members_hash[gh_team.to_sym].each { |user_cn|
        gl_org_id = gl.get_groups_hash()[gh_org_name.to_s]
        if (!gl_org_id)
          gl_org_id = gl.create_or_get_group_id(gh_org_name)
        end
        user_hash = cn_user_info_hash[user_cn]
        if user_hash
          user_id = user_hash[:samaccountname].downcase
          if (gh_team =~ /Owners$/)
            perm = 50
          else
            perm = 30
          end
          if (gl.get_users_cn_hash()[user_cn])
            if(!gl.is_group_member(gl_org_id, gl.get_users_cn_hash()[user_cn]))
              puts("#{user_id} added to #{gh_org_name}")
              gl.add_dev_to_group(
                gl.get_users_cn_hash()[user_cn], gl_org_id, perm)
            #else
              #puts("#{user_id} already a member of #{gh_org_name}")
            end
          else
            puts("Can't find #{user_id} #{user_cn}")
          end
        end
      }
    }
  }
end

update_perms
