require 'fastimage'
require 'open-uri'

module MirrorImage
  def mirror_image_to_s3(url, name)
    return false unless type = FastImage.type(url)

    obj = S3::BUCKET.objects.create("#{name}.#{type}", OpenURI.open_uri(url), acl: :public_read)

    obj.public_url.to_s
  rescue
    false
  end

  extend self
end
