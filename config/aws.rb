# A namespace to encapsulate Amazon S3 related constants
module S3
  # If we have a key and a bucket for S3, create a client
  CLIENT = if ENV['AWS_KEY'] && ENV['AWS_BUCKET']
    require 'aws-sdk'
    puts "Connecting to Amazon S3"
    Aws::S3::Client.new
  end

  # And if we end up with a client..
  if CLIENT
    # Create the bucket if it doesn't exist
    unless CLIENT.buckets[ENV['AWS_BUCKET']].exists?
      puts "Creating bucket on Amazon S3"
      CLIENT.buckets.create(ENV['AWS_BUCKET'])
    end

    # Get hold of the bucket (doing a check for it, if necessary)
    BUCKET = if ENV['AWS_BUCKET_CHECK']
      puts "#{ENV['AWS_BUCKET']} bucket attached"
      CLIENT.buckets[ENV['AWS_BUCKET']]
    else
      begin
        CLIENT.buckets[ENV['AWS_BUCKET']].acl
        puts "#{ENV['AWS_BUCKET']} bucket successfully accessed"
        CLIENT.buckets[ENV['AWS_BUCKET']]
      rescue
        puts "ERROR - #{ENV['AWS_BUCKET']} bucket could not be accessed"
        nil
      end
    end
  end
end
