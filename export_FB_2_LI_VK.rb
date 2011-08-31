
require 'mechanize'
require 'yaml'
require 'ap'


# FaceBook Settings
settingsFB = { :email       => '',
               :password    => '',
               :login_page  => 'http://m.facebook.com/',
               :group_url   => 'http://m.facebook.com/LAMPUserGroupDnipro'
}

# LinkedIn Settings
settingsLI = { :email       => '',
               :password    => '',
               :login_page  => 'http://www.linkedin.com/',
               :group_url   => 'http://www.linkedin.com/groups/LAMP-User-Group-Dnipro-4025860?home=&gid=4025860&trk=anet_ug_hm',
               :twitter_id  => ''
}

# Vkontakte Settings
settingsVK = { :email       => '',
               :password    => '',
               :login_page  => 'http://m.vkontakte.ru/login?fast=1&hash=&s=0&to=',
               :group_url   => 'http://m.vkontakte.ru/group29102426'
}


# Init Posts DB
def initialize_db file_name = 'posts_db.yaml'
  begin
    return_data = YAML::load(File.open( File.join(File.dirname(__FILE__), file_name) ))
  rescue
    return_data = []
    save_db [], file_name
  end
  return_data
end

# Save Posts DB
def save_db data, file_name = 'posts_db.yaml'
    File.open(File.join(File.dirname(__FILE__), file_name), 'w') do |f|
	    f.print data.to_yaml
    end
end


# login to FB
def login_to_fb settings, agent
  puts '*** Login to facebook'

  agent.get (settings[:login_page])

  form = agent.page.forms.first
  form.email = settings[:email]
  form.pass = settings[:password]
  verify_page = form.submit

  if verify_page.uri.path == 'login.php?m=1&email=*'
    ap "***** Login Failed"
    return false
  end
  ap "OK"
  true
end


# login to LinkedIn
def login_to_li settings, agent
  puts '********* Login to LinkedIn **************'

  agent.get (settings[:login_page])

  form = agent.page.forms.first
  form.session_key = settings[:email]
  form.session_password = settings[:password]
  verify_page = form.submit

  if verify_page.uri.path == 'uas/login-submit'
    ap "***** Login Failed"
    return false
  end
  ap "OK"
  true
end

# login to VK
def login_to_vk settings, agent
  puts '********* Login to vkontakte **************'

  agent.get (settings[:login_page])

  form = agent.page.forms.first
  form.email = settings[:email]
  form.pass = settings[:password]
  verify_page = form.submit

  if verify_page.uri.path == 'login.php?login_attempt=1'
    ap "***** Login Failed"
    return false
  end
  ap "OK"
  true
end


# grab FB group page
def export_posts settings, posts, agent
  puts '********* Grab from Facebook  **************'

  agent.get (settings[:group_url])

  new_posts = []
  cont = true
  while agent.page.link_with(:text => "See More Posts") && cont
    i = 1
    post = {}
    post_no = 0

    agent.page.links_with(:href => /l\.php\?u=/).each do |link|
      if i %2 ==0
        post[:title] = link.text
        post_no += 1
        unless posts.include? post
          new_posts << post
          ap '<===[FB] ' + post[:title]
          post = {}
        else
          cont = false
        end
      else
        post[:link] = link.text
      end
      i+=1
    end

    agent.page.link_with(:text => "See More Posts").click
    puts "* Next Page " + agent.page.link_with(:text => "See More Posts").href unless agent.page.link_with(:text => "See More Posts").nil?

  end

  new_posts.reverse

end


# import posts to LinkedIn
def import_posts_to_li settings, posts, agent
  puts '********* Post to LinkedIn **************'

  posts.each do |post|
    agent.get (settings[:group_url])
    form = agent.page.forms_with(:action => '/groups').first
    form.postTitle = "#{post[:link]} | #{post[:title]}"
    form.postText ="#{post[:link]} #{10.chr} #{post[:title]}"
    form.field_with(:id => "post-twit-account-select").value = settings[:twitter_id]
    form.checkbox_with(:name => /tweet/).check
    form.submit
    ap '[LI]===> ' + post[:title]
  end

end

# import posts to Vkontakte
def import_posts_to_vk settings, posts, agent
  puts '********* Post to Vkontakte **************'

  posts.each do |post|
    agent.get (settings[:group_url])
    form = agent.page.forms.first
    form.message = "#{post[:link]} #{10.chr} #{post[:title]}"
    form.submit
    ap '[VK]===> ' + post[:title]
    sleep 10
  end

end


# Main
#############  grab from Facebook ###############
agent = Mechanize.new
login_to_fb settingsFB, agent

posts =  initialize_db
new_posts = export_posts settingsFB, posts, agent
posts += new_posts
save_db posts

# logs
puts '=====posts=============='
ap posts
puts '=====new_posts=============='
ap new_posts

unless new_posts.empty?
  #############  post to LinkedIn ###############
  agent = Mechanize.new
  login_to_li settingsLI, agent
  import_posts_to_li settingsLI, new_posts, agent
  #############  post to Vkontakte ###############
  agent = Mechanize.new
  login_to_vk settingsVK, agent
  import_posts_to_vk settingsVK, new_posts, agent
  #################################################
end
