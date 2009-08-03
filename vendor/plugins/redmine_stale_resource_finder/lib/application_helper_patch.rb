module RedmineStaleResourceFinderMixins
  module ApplicationHelperPatch
    def self.included(base)
      base.class_eval do

        def clippy(text, bgcolor='#FFFFFF')
          html = <<-EOF
            <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
                    width="110"
                    height="14"
                    id="clippy" >
            <param name="movie" value="/plugin_assets/redmine_stale_resource_finder/flash/clippy.swf"/>
            <param name="allowScriptAccess" value="always" />
            <param name="quality" value="high" />
            <param name="scale" value="noscale" />
            <param NAME="FlashVars" value="text=#{text}">
            <param name="bgcolor" value="#{bgcolor}">
            <embed src="/plugin_assets/redmine_stale_resource_finder/flash/clippy.swf"
                   width="110"
                   height="14"
                   name="clippy"
                   quality="high"
                   allowScriptAccess="always"
                   type="application/x-shockwave-flash"
                   pluginspage="http://www.macromedia.com/go/getflashplayer"
                   FlashVars="text=#{text}"
                   bgcolor="#{bgcolor}"
            />
            </object>
          EOF
        end

        # It would be great to just override textilizable here but I can't figure
        # out how to make that work easily.

      end
    end
  end
end

ApplicationHelper.send(:include, RedmineStaleResourceFinderMixins::ApplicationHelperPatch)

