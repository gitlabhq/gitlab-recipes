# Community contributed script to import from GitHub to GitLab
# It imports repositories, issues and the wiki's.
# This script is not maintained, please send merge requests to improve it, do not file bugs.
# The issue import might concatenate all comments of an issue into one, if so feel free to fix this.

require 'bundler/setup'
require 'octokit'
require 'optparse'
require 'git'
require 'gitlab'
require 'pp'

#deal with options from cli, like username and pw
options = {:usr => nil,
           :pw => nil,
           :api => 'https://api.github.com',
           :web => 'https://github.com/',
           :space => nil,
           :group => nil,
           :ssh => false,
           :private => false,
           :gitlab_api => 'http://gitlab.example.com/api/v3',
           :gitlab_token => 'secret'
           }
optparse = OptionParser.new do |opts|
  opts.on('-u', '--user USER', "user to connect to GitHub with") do |u|
    options[:usr] = u
  end
  opts.on('-p', '--pw PASSWORD', 'password for user to connect to GitHub with') do |p|
    options[:pw] = p
  end
  opts.on('--api API', String, 'API endpoint for GitHub') do |a|
    options[:api] = a
  end
  opts.on('--gitlab-api API', String, 'API endpoint for GitLab') do |a|
    options[:gitlab_api] = a
  end
  opts.on('-t', '--gitlab-token TOKEN', String, 'Private token for GitLab') do |t|
    options[:gitlab_token] = t
  end
  opts.on('--web', 'Web endpoint for GitHub') do |w|
    options[:web] = w
  end
  opts.on('--ssh', 'Use ssh for GitHub') do |s|
    options[:ssh] = s
  end
  opts.on('--private', 'Import only private GitHub repositories (enables ssh)') do |p|
    options[:private] = p
    options[:ssh] = true
  end
  opts.on('-s', '--space SPACE', 'The space to import repositories from (User or Organization)') do |s|
    options[:space] = s
  end
  opts.on('-g', '--group GROUP', 'The GitLab group to import projects to') do |g|
    options[:group] = g
  end
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!
if options[:usr].nil? or options[:pw].nil?
  puts "Missing parameter ..."
  puts options
  exit
end

if options[:group].nil?
  if options[:space].nil?
    raise 'Both group and space can\'t be empty!'
  end
  
  options[:group] = options[:space]
end

Octokit.configure do |c|
  c.api_endpoint = options[:api]
  c.web_endpoint = options[:web]
end

#set the gitlab options
Gitlab.configure do |c|
  c.endpoint = options[:gitlab_api]
  c.private_token = options[:gitlab_token]
end

#setup the clients
gh_client = Octokit::Client.new(:login => options[:usr], :password => options[:pw])
gl_client = Gitlab.client()
#get all of the repos that are in the specified space (user or org)
gh_repos = gh_client.repositories(options[:space], {:type => options[:private] ? 'private' : 'all'})
gh_repos.each do |gh_r|
  #
  ## clone the repo from the github server
  #
  git_repo = nil
  if File.directory?("/tmp/clones/#{gh_r.name}")
    git_repo = Git.open("/tmp/clones/#{gh_r.name}")
    git_repo.pull
  else
    git_repo = Git.clone(options[:ssh] ? gh_r.ssh_url : gh_r.git_url, gh_r.name, :path => '/tmp/clones')
  end
  
  `for branch in $(git --git-dir /tmp/clones/#{gh_r.name}/.git branch -a | grep remotes | grep -v HEAD | grep -v master); do git --git-dir /tmp/clones/#{gh_r.name}/.git branch --track ${branch##*/} $branch;  done`

  #
  ## Push the cloned repo to gitlab
  #
  project_list = []

  push_group = nil
  #I should be able to search for a group by name
  gl_client.groups.each do |g|
    if g.name == options[:group]
      push_group = g
    end
  end

  #if the group wasn't found, create it
  if push_group.nil?
    push_group = gl_client.create_group(options[:group], options[:group])
  end

  #edge case, gitlab didn't like names that didn't start with an alpha. Can't remember how I ran into this.
  name = gh_r.name
  if gh_r.name !~ /^[a-zA-Z]/
    name = "gh-#{gh_r.name}"
  end

  puts gh_r.name
  #create and push the project to GitLab
  new_project = gl_client.create_project(name)
  git_repo.add_remote("gitlab", new_project.ssh_url_to_repo)
  git_repo.push('gitlab', '--all')
  
  # Copy labels for this project
  labels = gh_client.labels(gh_r.full_name)
  labels.each do |l|
    gl_client.create_label(new_project.id, l.name, '#'+l.color)
  end

  #
  ## Look for issues in GitHub for this project and push them to GitLab
  ## I wish the GitLab API let me create comments for issues. Oh well, smashing it all into the body of the issue.
  #
  if gh_r.has_issues
    issues = []
    
    # Get opened issues
    page = 1
    loop do
      issues_ = gh_client.list_issues(gh_r.full_name, :page => page)
      issues.concat(issues_)
      page = page + 1
      break if issues_.size() < 30 # Github returns 30 issues per page
    end
    
    # Get closed issues
    page = 1
    loop do
      issues_ = gh_client.list_issues(gh_r.full_name, :page => page, :state => 'closed')
      issues.concat(issues_)
      page = page + 1
      break if issues_.size() < 30
    end
    
    issues.sort_by! { |i| i.number } # Sorting isues by number
    
    issues.each do |i|
      comments = gh_client.issue_comments(gh_r.full_name, i['number'])
      body = i.body
      if comments.any?
	body += "\n\n\nComments from GitHub import:\n"
	comments.each do |c|
	  body += "\n\n#{c.body}\nBy #{c.user.login} on #{c.created_at}"
	end
      end
      
      labels = i.labels.map {|l| l.name }.join(sep=',')
      
      gl_issue = gl_client.create_issue(new_project.id, i.title, :description => body, :labels => labels)
      
      if i.state == 'closed'
	gl_client.close_issue(new_project.id, gl_issue.id)
      end
      
      pp i.number.to_s + ' ' + i.title + ' ' + i.state + ' ' + labels
    end
  end

  #
  ## Look for wiki pages for this repo in GitHub and migrate them to GitLab
  #
  if gh_r.has_wiki
    #this is dumb. The only way to know if a repo has a wiki is to attempt to clone it and then ignore failure if it doesn't have one
    begin
      gh_wiki_url = gh_r.git_url.gsub(/\.git/, ".wiki.git")
      wiki_name = gh_r.name + '.wiki'
      wiki_repo = Git.clone(gh_wiki_url, wiki_name, :path => '/tmp/clones')

      #this is a pain, have to visit the wiki page on the web ui before being able to work with it as a git repo
      `wget -q --save-cookies /tmp/junk/gl_login.txt -P /tmp/junk --post-data "username=#{options[:usr]}&password=#{options[:pw]}" gitlab.example.com/users/auth/ldap/callback`
      `wget -q --load-cookies /tmp/junk/gl_login.txt -P /tmp/junk -p #{new_project.web_url}/wikis/home`
      `rm -fr /tmp/junk/*`

      gl_wiki_url = new_project.ssh_url_to_repo.gsub(/\.git/, ".wiki.git")
      wiki_repo.add_remote('gitlab', gl_wiki_url)
      wiki_repo.push('gitlab')
    rescue
    end
  end

  # change the owner of this new project to the group we found it in
  gl_client.transfer_project_to_group(push_group.id, new_project.id)
end
