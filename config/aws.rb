module S3
  CLIENT = if ENV['AWS_KEY'] && ENV['AWS_BUCKET']
    require 'aws-sdk'
    puts "Connecting to Amazon S3"
    AWS.config access_key_id: ENV['AWS_KEY'], secret_access_key: ENV['AWS_SECRET']
    AWS::S3.new
  end

  if CLIENT
    unless CLIENT.buckets[ENV['AWS_BUCKET']].exists?
      puts "Creating bucket on Amazon S3"
      CLIENT.buckets.create(ENV['AWS_BUCKET'])
    end

    BUCKET = begin
      CLIENT.buckets[ENV['AWS_BUCKET']].acl
      puts "#{ENV['AWS_BUCKET']} bucket successfully accessed"
      CLIENT.buckets[ENV['AWS_BUCKET']]
    rescue
      puts "ERROR - #{ENV['AWS_BUCKET']} bucket could not be accessed"
      nil
    end
  end


end
