require 'fastimage'
require 'open-uri'

# Given a URL, work out what type of image it is then mirror it to our S3 bucket
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
