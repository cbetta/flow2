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
    return false unless CONTENT_TYPES[type.to_sym]

    filename = "#{name}.#{type}"
    puts "UPLOADIN"

    options = {
      bucket: ENV['AWS_BUCKET'],
      key: filename,
      body: OpenURI.open_uri(url).read,
      acl: 'public-read',
      content_type: CONTENT_TYPES[type.to_sym]
    }
    puts options.inspect

    obj = S3::CLIENT.put_object(options)

    puts "UPLOADED"

    "https://#{ENV['AWS_BUCKET']}.s3.amazonaws.com/#{filename}"
  rescue Exception => error
    puts error.inspect
  #   false
  end

  extend self
end
