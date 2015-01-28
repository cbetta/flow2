require 'fastimage'
require 'open-uri'

# Given a URL, work out what type of image it is then mirror it to our S3 bucket
module MirrorImage
  CONTENT_TYPES = {
  	jpeg: "image/jpeg",
  	jpg: "image/jpeg",
  	gif: "image/gif",
  	png: "image/png",
  	apng: "image/png"
  }

  def mirror_image_to_s3(url, name)
  	return false unless S3::CLIENT
    return false unless type = FastImage.type(url)

    obj = S3::BUCKET.objects.create("#{name}.#{type}", OpenURI.open_uri(url), acl: :public_read, content_type: CONTENT_TYPES[type.to_sym])

    obj.public_url.to_s
  rescue
    false
  end

  extend self
end
