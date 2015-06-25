require 'set'
require 'cgi'
require 'gitlab'

class Gitlab::Client
  # for some reason these don't exist in the gem api impl. :(
  # so we'll add our own defs for the missing api implementations
  module Users
    def create_key_for_user_id(user_id, title, key)
      post("/users/#{user_id}/keys", :body => {:title => title, :key => key})
    end
  end

  module Projects
    def edit_project(project_id, options={})
      put("/projects/#{project_id}", :body => options)
    end
  end

end


module Jk
  class Gitlabz

    def initialize(api_endpoint, admin_token)
      @gl_client = Gitlab::Client.new(
        :endpoint => api_endpoint,
        :private_token => admin_token)
      @user_cn_hash = {}
      @user_id_hash = {}
      @group_id_hash = {}
      @proj_name_id_hash = {}
      @per_page = 100
    end

    def add_key_for_user(user_name, key_name, key)
      user_id = get_users_id_hash()[user_name]
      return if !user_id
      begin
        @gl_client.create_key_for_user_id(user_id, key_name, key)
      rescue Gitlab::Error::BadRequest => br
        # if this key exists we don't care
      end
    end

    def get_users_id_hash
      return @user_id_hash if @user_id_hash.size > 0

      page = 1
      loop {
        user_arr = @gl_client.users(
          {:per_page => @per_page, :page => page})
        user_arr.each { |user|
          @user_id_hash[user.username.downcase] = user.id
        }
        page += 1
        break if user_arr.size < @per_page
      }
      @user_id_hash
    end

    def get_users_cn_hash(force_update = false)
      return @user_cn_hash if @user_cn_hash.size > 0 && !force_update

      page = 1
      loop {
        user_arr = @gl_client.users(
          {:per_page => @per_page, :page => page})
        user_arr.each { |user|
          if (user.identities.size > 0)
            extern_uid = user.identities[0]["extern_uid"]
            @user_cn_hash[extern_uid] = user.id
          end
        }
        page += 1
        break if user_arr.size < @per_page
      }
      @user_cn_hash
    end

    def is_group_member(group_id, user_id)
      if (!@group_members_hash)
        @group_members_hash = {}
      else
        if (!@group_members_hash[group_id])
          @group_members_hash[group_id] = get_group_members(group_id)
        end
        return @group_members_hash[group_id].include?(user_id)
      end
    end

    def get_group_members(group_id)
      ret_set = Set.new()
      page = 1
      loop {
        group_mem = @gl_client.group_members(group_id,
          {:per_page => @per_page, :page => page})
        group_mem.each { |member|
          ret_set.add(member.id)
        }
        page += 1
        break if group_mem.size < @per_page
      }
      ret_set
    end

    def get_groups_hash
      return @group_id_hash if @group_id_hash.size > 0

      page = 1
      loop {
        group_arr = @gl_client.groups(
          {:per_page => @per_page, :page => page})
        group_arr.each { |group|
          @group_id_hash[group.name] = group.id
        }
        page += 1
        break if group_arr.size < @per_page
      }
      @group_id_hash
    end

    def add_dev_to_group(user_id, group_id, perm="30")
      begin
        @gl_client.add_group_member(group_id, user_id, perm)
      rescue Exception => nfe
        puts(nfe)
      end
    end

    def add_user(email, password, username, name, ldap_cn, bio)
      username = username.downcase
      if ! get_users_id_hash()[username]
        user = @gl_client.create_user(
          email,
          password,
          :username => username,
          :name => name,
          :provider => "ldap",
          :extern_uid => ldap_cn,
          :bio => bio,
          :confirm => 0
        )
        get_users_id_hash()[user.username] = user.id
      end
      get_users_id_hash()[username]
    end

    def create_or_get_group_id(org_name)
      begin
        group = @gl_client.group(org_name)
      rescue Gitlab::Error::NotFound => nfe
        group = @gl_client.create_group(org_name, org_name)
        @group_id_hash[group.name] = group.id
      end
      return group.id
    end

    def create_and_get_project_id(repo_name, org_name)
      new_repo_name = repo_name.gsub('.', '_')
      puts("Creating #{org_name}/#{new_repo_name}")
      #begin
        #project = @gl_client.project(CGI.escape(org_name + "/" + repo_name))
      #rescue Gitlab::Error::NotFound => nfe
        group_id = create_or_get_group_id(org_name)
        project = @gl_client.create_project(
          new_repo_name,
          :namespace_id => group_id
        )
        # gitlab won't allow us to create repos that are Camel Cased or have
        # dots in the name (super cool) but it will let me rename them
        # once I create them (makes total sense)
        @gl_client.edit_project(project.id, :name => repo_name, :path => repo_name)
      #end
      return project.id
    end

    def edit_project_name(org_name, new_name, curr_name)
      begin
        project = @gl_client.project(CGI.escape(org_name + "/" + curr_name))
        @gl_client.edit_project(project.id, :name => new_name, :path => new_name)
        return project.id
      rescue Gitlab::Error::NotFound => nfe
        puts("#{curr_name} not found")
      end
    end

    def get_project_name_id_hash
      return @proj_name_id_hash if @proj_name_id_hash.size > 0
      page = 1
      loop {
        pa = @gl_client.projects(:per_page => @per_page, :page => page)
        pa.each { |proj|
          @proj_name_id_hash[proj.path_with_namespace] = proj.id
        }
        page += 1
        break if pa.size < @per_page
      }
      @proj_name_id_hash
    end

    def create_issue(repo_full_name, title, body)
      #begin
        project_id = get_project_name_id_hash()[repo_full_name]
        gl_issue = @gl_client.create_issue(project_id, title, :description => body)
        @gl_client.close_issue(project_id, gl_issue.id)
      #rescue Exception => e
        #puts(e)
      #end
    end

    def unprotect_branches_for_project(project_id)
      @gl_client.branches(project_id).each { |branch|
        puts("Unprotecting #{project_id} #{branch.name}")
        @gl_client.unprotect_branch(project_id, branch.name)
      }
    end

    def add_hook_to_proj(proj_id, url)
      hooks = @gl_client.project_hooks(proj_id, :per_page => @per_page)
      hooks.each { |hook|
        if(hook.url == url)
          #puts("#{url} already added to proj id #{proj_id}")
          return
        end
      }

      puts("Adding #{url} to proj id #{proj_id}")
      @gl_client.add_project_hook(
        proj_id,
        url,
        :push_events => 1,
        :issues_events => 0,
        :merge_requests => 0,
        :tag_push_events => 0
      )
    end
  end
end
