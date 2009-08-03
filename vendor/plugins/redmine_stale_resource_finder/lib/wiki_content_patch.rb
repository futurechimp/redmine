require_dependency 'wiki_content'
require_dependency 'versioned_image_resource'

module WikiContentPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def has_stale_resources?
      !stale_embedded_images.empty?
    end

    def stale_embedded_images
      project = self.page.wiki.project
      image_embed_strings = self.text.scan(/wireframe:(\S*.(bmp|gif|jpg|jpeg|png))@(\d*)/i)
      stale_images = []
      image_embed_strings.each do |path, ext, rev|
        image_resource = VersionedImageResource.new(path, rev, project)
        stale_images << image_resource if image_resource.is_stale?
      end
      return stale_images
    end

  end

end


# Add module to WikiContent
WikiContent.send(:include, WikiContentPatch)

