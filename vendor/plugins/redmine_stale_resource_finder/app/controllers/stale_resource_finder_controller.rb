class StaleResourceFinderController < ApplicationController

  unloadable

  def index
    @stale_resources = []
    @project = Project.find(params[:project_id])
    @repo = @project.repository
    @repo.fetch_changesets
    unless @project.wiki.pages.empty?
      @project.wiki.pages.each do |p|
        @stale_resources << p if p.content.has_stale_resources?
      end
    end
  end
  
end
