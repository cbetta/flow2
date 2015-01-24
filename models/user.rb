require 'digest/md5'

class User < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :username
  attribute :uid
  attribute :fullname
  attribute :approved
  collection :posts, :Post
  collection :comments, :Comment
  attribute :created_at, Type::Time
  attribute :metadata, Type::Hash

  def before_create
    self.created_at = Time.now
  end

  def avatar
    return false unless self.metadata['email'].to_s.length > 5
    %{http://www.gravatar.com/avatar.php?gravatar_id=#{Digest::MD5.hexdigest(self.metadata['email'])}&size=64}
  end

  def avatar?; avatar end
end
