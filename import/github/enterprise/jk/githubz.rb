require 'set'
require 'octokit'

module Jk
  class Githubz

    def initialize(login, password, api_endpoint, web_endpoint)
      @gh_client = Octokit::Client.new(
        :login => login,
        :password => password,
        :api_endpoint => api_endpoint,
        :web_endpoint => web_endpoint
      )
      @per_page=100
    end

    def get_org_repo_hash
      org_repo_hash = {}
      @gh_client.organizations(:per_page => @per_page).each { |org|
        org_repo_hash[org.login] = []
        repos = @gh_client.repositories(org.login, :per_page => @per_page)
        repos.each { |repo|
          org_repo_hash[org.login].push(repo.name)
        }
      }
      return org_repo_hash
    end

    def get_org_teams
      org_teams = {}
      team_members = {}
      @gh_client.organizations.each { |org|
        org_teams[org.login.to_sym] = []
        ts = @gh_client.organization_teams(org.login)
        ts.each { |t|
          if (t.name == 'Owners')
             team_name = org.login + '.' + t.name
          else
             team_name = t.name
          end
          org_teams[org.login.to_sym].push(team_name)
          team_members[team_name.to_sym] = [] if !team_members[team_name.to_sym]
          members = @gh_client.team_members(t.id)
          members.each { |m|
            team_members[team_name.to_sym].push(m.login.downcase)
          }
        }
      }
      # I could have just created Sets to begin with but whatevs
      # simple hack to get rid of dupes
      team_members.each { |k,v| team_members[k] = Set.new(team_members[k]).to_a }
      return org_teams, team_members
    end

    def get_user_key_hash
      user_keys = {}
      last_id_seen = 0;

      users = []
      loop {
        users_ = @gh_client.all_users(:since => last_id_seen)

        if (users_.size > 0)
          cur_last_id = users_[users_.size - 1].id
          if (last_id_seen == cur_last_id)
            break
          end
          last_id_seen = cur_last_id
          users.concat(users_)
        else
          break
        end
      }

      users.each { |user|
        next if user.id == 1 || user.type != 'User'
        user_login = user.login.downcase
        user_keys[user_login] = []
        @gh_client.user_keys(user_login).each { |key|
          user_keys[user_login].push(key.key)
        }
      }
      user_keys
    end

    # return array of hashes containing pull request number, title, commits,
    # and comments
    def get_pull_requests_comments_for_repo(repo_full_name)
      return_array = []

      page = 1
      prs = []

      begin
        loop {
          prs_ = @gh_client.pull_requests(repo_full_name, :per_page => @per_page,
            :state => 'closed', :page => page)
          prs.concat(prs_)
          page += 1
          break if prs_.size < @per_page
        }
        page = 1
        loop {
          prs_ = @gh_client.pull_requests(repo_full_name, :per_page => @per_page,
            :state => 'open', :page => page)
          prs.concat(prs_)
          page += 1
          break if prs_.size < @per_page
        }
      rescue Exception => e
        puts("Unable to get pull requests for #{repo_full_name} #{e}")
        return return_array
      end

      prs.sort_by! { |p| p.number }

      if (prs.size == 0)
        puts("#{repo_full_name} has no pull requests")
      end

      cnt = 1
      prs.each { |pr|
        # if we don't have contiguous pull request numbers we'll create
        # a dummy to keep our pull request numbers equal from github to gitlab
        # this happens if an issue was created in github which was not
        # an actual pull request. We're only migrating pull requests here.
        while (pr.number > cnt)
          puts("making dummy #{pr.number} #{cnt}")
          current_pull_hash = {}
          current_pull_hash[:number] = cnt
          current_pull_hash[:title] = "Dummy issue"
          current_pull_hash[:body] = ""
          current_pull_hash[:commits] = []
          current_pull_hash[:comments] = []
          return_array.push(current_pull_hash)
          cnt += 1
        end
        puts("getting #{repo_full_name}##{pr.number} #{cnt}")
        cnt += 1

        current_pull_hash = {}
        current_pull_hash[:number] = pr.number
        current_pull_hash[:title] = pr.title
        current_pull_hash[:body] = pr.body

        # COMMITS ----------------------------------------
        page = 1
        #commits = []
        #loop {
          commits = @gh_client.pull_request_commits(repo_full_name, pr.number,
            :per_page => @per_page, :page => page)
          #commits.concat(commits_)
          #page += 1
          #break if commits_.size < @per_page
        #}

        current_pull_hash[:commits] = []
        commits.each { |c|
          commit_hash = {}
          user = c.commit.author.email
          user = user[0,(user.rindex('@')||user.length)]
          commit_hash[:username] = user
          commit_hash[:sha] = c.sha[0,7]
          commit_hash[:date] = c.commit.author.date
          commit_hash[:message] = c.commit.message
          current_pull_hash[:commits].push(commit_hash)
        }

        # COMMENTS ----------------------------------------
        page = 1
        comments = []
        #loop {
          comments.concat(@gh_client.pull_request_comments(
            repo_full_name, pr.number, :per_page => @per_page, :page => page))
          comments.concat(@gh_client.issue_comments(repo_full_name, pr.number,
            :per_page => @per_page, :page => page))
            #:per_page => @per_page, :page => page)
          #comments.concat(comments_)
          #page += 1
          #break if comments_.size < @per_page
        #}
        current_pull_hash[:comments] = []
        comments.each { |c|
          comment_hash = {}
          comment_hash[:username] = c.user.login
          comment_hash[:date] = c.created_at
          comment_hash[:body] = c.body
          current_pull_hash[:comments].push(comment_hash)
        }
        return_array.push(current_pull_hash)
      }
      return_array
    end
  end
end
