require 'redmine'
require_dependency 'application_helper_patch'
require_dependency 'wiki_content_patch'

#Dir[File.join(directory,'vendor','plugins','*')].each do |dir|
#  path = File.join(dir, 'lib')
#  $LOAD_PATH << path
#  Dependencies.load_paths << path
#  Dependencies.load_once_paths.delete(path)
#end




RAILS_DEFAULT_LOGGER.info 'Starting Stale Resource Finder Plugin for Redmine'

Redmine::Plugin.register :redmine_stale_resource_finder do
  name 'Stale Resource Finder'
  author 'David Hrycyszyn'
  description "Checks a project's wiki to see whether there are newer versions of any images embedded in the pages within the project's source code repo."
  version '0.0.1'
  
  permission :stale_resource_finder, {:stale_resource_finder => [:index]}, :public => true
  menu :project_menu, :stale_resource_finder, { :controller => 'stale_resource_finder', :action => 'index' }, :caption => 'Stale resource finder', :after => :activity, :param => :project_id  
end
