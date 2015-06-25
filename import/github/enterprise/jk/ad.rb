require 'net/ldap'

module Jk
  class Ad

    def initialize(host, username, password, base)
      @ldap = Net::LDAP.new :host => host,
        :port => 389,
        :auth => {
          :method => :simple,
          :username => username,
          :password => password
        }
      @treebase = base
    end

    def get_user_login_from_cn(user_name, search_term = "cn")
      attrs = ['samaccountname', 'title', 'displayname', 'memberOf']
      user_hash = {}

      filter = Net::LDAP::Filter.eq(search_term, user_name)

      @ldap.search(:base => @treebase, :filter => filter,
          :attributes => attrs) { |ls|
        ls.each { |key, vals|
          vals.each { |val|
            user_hash[key] = val
          }
        }
      }
      return user_hash
    end

    def get_user_cn_from_login(user_name, search_term = "samaccountname")
      atr = 'dn'
      attrs = [atr]
      users_hash = {}

      filter = Net::LDAP::Filter.eq(search_term, user_name)

      @ldap.search(:base => @treebase, :filter => filter,
          :attributes => attrs) { |entry|
        entry[atr.to_sym].each { |value|
          if (value =~ /^CN=(.+)/) then
            user_name = value
          end
        }
      }
      return user_name
    end

    def get_ldap_group_members_info_hash(group_name)
      mem_atr = 'member'

      attrs = [mem_atr]
      users_hash = {}

      filter = Net::LDAP::Filter.eq("cn", group_name)

      @ldap.search(:base => @treebase, :filter => filter,
          :attributes => attrs) { |entry|

        entry[mem_atr.to_sym].each { |value|
          if (value =~ /^CN=([^,]+)/) then
            user_name = $1
            user_cn = value
            user_info = get_user_login_from_cn(user_name);
            users_hash[user_cn] = user_info
          end
        }
      }
      return users_hash
    end

    def get_ldap_group_members_cn_array(group_name)
      mem_atr = 'member'
      attrs = [mem_atr]
      users_arr = []

      filter = Net::LDAP::Filter.eq("cn", group_name)

      # if this group exists in AD we want to get the current group
      # members
      @ldap.search(:base => @treebase, :filter => filter,
          :attributes => attrs) { |entry|
        entry[mem_atr.to_sym].each { |value|
          if (value =~ /^CN=([^,]+)/) then
            user_name = $1
            user_cn = value
            users_arr.push(user_cn)
          end
        }
      }
      return users_arr
    end

    # Pass in a hash of team_name => members and a hash of org_name => teams
    # Gitlab has no concept of teams so we'll just grant them access directly
    # to each gitlab group (github orgs == gitlab groups)
    #
    # From github, the team hash => member name array is in form of github logins
    # eg "sbody" or whatever
    # What we want to end up with is team_name => array of user_ldap_cns
    # eg "CN=Some Body,OU=Users,OU=ad,DC=testersDC=com"
    #
    # The reason we want a key of CN is due to querying ldap membership returning
    # only CNs. We want a quick lookup on that.
    def get_membership_hashes(orgs_hash, groups_hash, ldap_github_group)
      @ad_groups = groups_hash
      @orgs = orgs_hash

      github_ad_members = get_ldap_group_members_info_hash(ldap_github_group)

      @ad_groups.each { |ad_group_name, value|
        # if there is a ad group we'll pull members from there and
        # ignore what was already in this hash for this ad_group_name (which
        # likely came in from github and was an array of user_names
        # instead of CNs)
        user_hash_array = get_ldap_group_members_cn_array(ad_group_name)
        if (user_hash_array.size > 0)
          @ad_groups[ad_group_name] = user_hash_array
        else
          # if there was no corresponding ad group then we'll replace
          # the user names with CNs
          # eg: "sbody" becomes "CN=Some Body,OU=Users,OU=testers,DC=com"
          user_cns = []
          @ad_groups[ad_group_name].each { |user_name|
            user_cns.push(get_user_cn_from_login(user_name))
          }
          @ad_groups[ad_group_name] = user_cns
        end
      }
      return @orgs, @ad_groups, github_ad_members
    end

  end

end
