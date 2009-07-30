require 'cgi'

class VersionedImageResource
  
  attr_reader :embedded_version, :repository_version, :resource_absolute_path, :path
  
  def initialize(path, rev, project)
    @project = project
    @path = path
    @embedded_version = rev.to_i
    @repository_version = get_rev_from_repository
    @resource_absolute_path = "/projects/#{project.id}/repository/entry/" + path
  end
  
  def is_stale?
    !@embedded_version.nil? && !@repository_version.nil? && @embedded_version < @repository_version 
  end
  
  def newest_version
    is_stale? ? @repository_version : @embedded_version
  end
  
  def path_to_version(version)
    @resource_absolute_path + "?rev=#{version}"
  end
  
  def revision_info_for(revision)
    @project.repository.entry(resource_path, revision).lastrev
  end  
  
  private
  
  def get_rev_from_repository
    revs = @project.repository.changesets_for_path("#{resource_path}")    
    rev_strings = revs.map(&:revision)
    rev_numbers = []
    rev_strings.each do |s|
      rev_numbers << s.to_i
    end
    rev_numbers.sort!
    rev_numbers.last 
  end  
  
  def resource_path
    return CGI.unescape(@path)
  end  
   
end