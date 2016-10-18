# A namespace to encapsulate Amazon S3 related constants
module S3
  # If we have a key and a bucket for S3, create a client
  CLIENT = if ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_BUCKET']
    require 'aws-sdk'
    puts "Connecting to Amazon S3"

    begin
      Aws::S3::Client.new.head_bucket(bucket: ENV['AWS_BUCKET'])
      Aws::S3::Client.new
    rescue Aws::S3::Errors::NotFound
      Aws::S3::Client.new.create_bucket(bucket: ENV['AWS_BUCKET'])
      Aws::S3::Client.new
    rescue Aws::S3::Errors::Forbidden
      puts "ERROR - #{ENV['AWS_BUCKET']} bucket could not be accessed"
      nil
    end
  end

end
