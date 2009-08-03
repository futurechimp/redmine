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

        # Formats text according to system settings.
        # 2 ways to call this method:
        # * with a String: textilizable(text, options)
        # * with an object and one of its attribute: textilizable(issue, :description, options)
        def textilizable(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}
          case args.size
          when 1
            obj = options[:object]
            text = args.shift
          when 2
            obj = args.shift
            text = obj.send(args.shift).to_s
          else
            raise ArgumentError, 'invalid arguments to textilizable'
          end
          return '' if text.blank?

          only_path = options.delete(:only_path) == false ? false : true

          # when using an image link, try to use an attachment, if possible
          attachments = options[:attachments] || (obj && obj.respond_to?(:attachments) ? obj.attachments : nil)

          if attachments
            attachments = attachments.sort_by(&:created_on).reverse
            text = text.gsub(/!((\<|\=|\>)?(\([^\)]+\))?(\[[^\]]+\])?(\{[^\}]+\})?)(\S+\.(bmp|gif|jpg|jpeg|png))!/i) do |m|
              style = $1
              filename = $6.downcase
              # search for the picture in attachments
              if found = attachments.detect { |att| att.filename.downcase == filename }
                image_url = url_for :only_path => only_path, :controller => 'attachments', :action => 'download', :id => found
                desc = found.description.to_s.gsub(/^([^\(\)]*).*$/, "\\1")
                alt = desc.blank? ? nil : "(#{desc})"
                "!#{style}#{image_url}#{alt}!"
              else
                m
              end
            end
          end

          text = Redmine::WikiFormatting.to_html(Setting.text_formatting, text) { |macro, args| exec_macro(macro, obj, args) }

          # different methods for formatting wiki links
          case options[:wiki_links]
          when :local
            # used for local links to html files
            format_wiki_link = Proc.new {|project, title, anchor| "#{title}.html" }
          when :anchor
            # used for single-file wiki export
            format_wiki_link = Proc.new {|project, title, anchor| "##{title}" }
          else
            format_wiki_link = Proc.new {|project, title, anchor| url_for(:only_path => only_path, :controller => 'wiki', :action => 'index', :id => project, :page => title, :anchor => anchor) }
          end

          project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)

          # Wiki links
          #
          # Examples:
          #   [[mypage]]
          #   [[mypage|mytext]]
          # wiki links can refer other project wikis, using project name or identifier:
          #   [[project:]] -> wiki starting page
          #   [[project:|mytext]]
          #   [[project:mypage]]
          #   [[project:mypage|mytext]]
          text = text.gsub(/(!)?(\[\[([^\]\n\|]+)(\|([^\]\n\|]+))?\]\])/) do |m|
            link_project = project
            esc, all, page, title = $1, $2, $3, $5
            if esc.nil?
              if page =~ /^([^\:]+)\:(.*)$/
                link_project = Project.find_by_name($1) || Project.find_by_identifier($1)
                page = $2
                title ||= $1 if page.blank?
              end

              if link_project && link_project.wiki
                # extract anchor
                anchor = nil
                if page =~ /^(.+?)\#(.+)$/
                  page, anchor = $1, $2
                end
                # check if page exists
                wiki_page = link_project.wiki.find_page(page)
                link_to((title || page), format_wiki_link.call(link_project, Wiki.titleize(page), anchor),
                                         :class => ('wiki-page' + (wiki_page ? '' : ' new')))
              else
                # project or wiki doesn't exist
                all
              end
            else
              all
            end
          end

          # Redmine links
          #
          # Examples:
          #   Issues:
          #     #52 -> Link to issue #52
          #   Changesets:
          #     r52 -> Link to revision 52
          #     commit:a85130f -> Link to scmid starting with a85130f
          #   Documents:
          #     document#17 -> Link to document with id 17
          #     document:Greetings -> Link to the document with title "Greetings"
          #     document:"Some document" -> Link to the document with title "Some document"
          #   Versions:
          #     version#3 -> Link to version with id 3
          #     version:1.0.0 -> Link to version named "1.0.0"
          #     version:"1.0 beta 2" -> Link to version named "1.0 beta 2"
          #   Attachments:
          #     attachment:file.zip -> Link to the attachment of the current object named file.zip
          #   Source files:
          #     source:some/file -> Link to the file located at /some/file in the project's repository
          #     source:some/file@52 -> Link to the file's revision 52
          #     source:some/file#L120 -> Link to line 120 of the file
          #     source:some/file@52#L120 -> Link to line 120 of the file's revision 52
          #     export:some/file -> Force the download of the file
          #  Wireframe:
          #    wireframe:some/image@52 -> Display revision 52 of /some/image in the project's repository
          #  Forum messages:
          #     message#1218 -> Link to message with id 1218
          text = text.gsub(%r{([\s\(,\-\>]|^)(!)?(attachment|document|version|commit|source|export|message|wireframe)?((#|r)(\d+)|(:)([^"\s<>][^\s<>]*?|"[^"]+?"))(?=(?=[[:punct:]]\W)|,|\s|<|$)}) do |m|
            leading, esc, prefix, sep, oid = $1, $2, $3, $5 || $7, $6 || $8
            link = nil
            if esc.nil?
              if prefix.nil? && sep == 'r'
                if project && (changeset = project.changesets.find_by_revision(oid))
                  link = link_to("r#{oid}", {:only_path => only_path, :controller => 'repositories', :action => 'revision', :id => project, :rev => oid},
                                            :class => 'changeset',
                                            :title => truncate_single_line(changeset.comments, :length => 100))
                end
              elsif sep == '#'
                oid = oid.to_i
                case prefix
                when nil
                  if issue = Issue.find_by_id(oid, :include => [:project, :status], :conditions => Project.visible_by(User.current))
                    link = link_to("##{oid}", {:only_path => only_path, :controller => 'issues', :action => 'show', :id => oid},
                                              :class => (issue.closed? ? 'issue closed' : 'issue'),
                                              :title => "#{truncate(issue.subject, :length => 100)} (#{issue.status.name})")
                    link = content_tag('del', link) if issue.closed?
                  end
                when 'document'
                  if document = Document.find_by_id(oid, :include => [:project], :conditions => Project.visible_by(User.current))
                    link = link_to h(document.title), {:only_path => only_path, :controller => 'documents', :action => 'show', :id => document},
                                                      :class => 'document'
                  end
                when 'version'
                  if version = Version.find_by_id(oid, :include => [:project], :conditions => Project.visible_by(User.current))
                    link = link_to h(version.name), {:only_path => only_path, :controller => 'versions', :action => 'show', :id => version},
                                                    :class => 'version'
                  end
                when 'message'
                  if message = Message.find_by_id(oid, :include => [:parent, {:board => :project}], :conditions => Project.visible_by(User.current))
                    link = link_to h(truncate(message.subject, :length => 60)), {:only_path => only_path,
                                                                      :controller => 'messages',
                                                                      :action => 'show',
                                                                      :board_id => message.board,
                                                                      :id => message.root,
                                                                      :anchor => (message.parent ? "message-#{message.id}" : nil)},
                                                       :class => 'message'
                  end
                end
              elsif sep == ':'
                # removes the double quotes if any
                name = oid.gsub(%r{^"(.*)"$}, "\\1")
                case prefix
                when 'document'
                  if project && document = project.documents.find_by_title(name)
                    link = link_to h(document.title), {:only_path => only_path, :controller => 'documents', :action => 'show', :id => document},
                                                      :class => 'document'
                  end
                when 'version'
                  if project && version = project.versions.find_by_name(name)
                    link = link_to h(version.name), {:only_path => only_path, :controller => 'versions', :action => 'show', :id => version},
                                                    :class => 'version'
                  end
                when 'commit'
                  if project && (changeset = project.changesets.find(:first, :conditions => ["scmid LIKE ?", "#{name}%"]))
                    link = link_to h("#{name}"), {:only_path => only_path, :controller => 'repositories', :action => 'revision', :id => project, :rev => changeset.revision},
                                                 :class => 'changeset',
                                                 :title => truncate_single_line(changeset.comments, :length => 100)
                  end
                when 'source', 'export'
                  if project && project.repository
                    name =~ %r{^[/\\]*(.*?)(@([0-9a-f]+))?(#(L\d+))?$}
                    path, rev, anchor = $1, $3, $5
                    link = link_to h("#{prefix}:#{name}"), {:controller => 'repositories', :action => 'entry', :id => project,
                                                            :path => to_path_param(path),
                                                            :rev => rev,
                                                            :anchor => anchor,
                                                            :format => (prefix == 'export' ? 'raw' : nil)},
                                                           :class => (prefix == 'export' ? 'source download' : 'source')
                  end
                when 'wireframe'
                  if project && project.repository
                    text = text.gsub(/wireframe:(\S*.(bmp|gif|jpg|jpeg|png))@(\d*)/i) do |m|
                      file = $1
                      rev = $3
                      image_url = ("/projects/#{project.id}/repository/entry/#{file}?rev=#{rev}")
                      link = image_tag(image_url)
                    end
                  end
                when 'attachment'
                  if attachments && attachment = attachments.detect {|a| a.filename == name }
                    link = link_to h(attachment.filename), {:only_path => only_path, :controller => 'attachments', :action => 'download', :id => attachment},
                                                           :class => 'attachment'
                  end
                end
              end
            end
            leading + (link || "#{prefix}#{sep}#{oid}")
          end

          text
        end

      end
    end
  end
end

ApplicationHelper.send(:include, RedmineStaleResourceFinderMixins::ApplicationHelperPatch)

