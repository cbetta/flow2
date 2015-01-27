require 'digest/md5'
require 'uri'

class User < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :username
  unique :username

  attribute :email
  attribute :fullname
  attribute :approved

  attribute :external_uid
  index :external_uid

  attribute :external_token

  attribute :avatar_url
  collection :posts, :Post
  collection :comments, :Comment
  attribute :created_at, Type::Time
  attribute :metadata, Type::Hash

  def set_metadata(hsh)
    self.metadata ||= {}
    self.metadata = self.metadata.merge hsh.map { |k, v| [k.to_s, v] }.to_h
  end

  def get_metadata(key)
    self.metadata[key.to_s]
  end

  def before_create
    self.created_at ||= Time.now
    self.metadata ||= {}
  end

  def gravatar_url
    return false unless self.email.to_s.length > 5
    %{http://www.gravatar.com/avatar.php?gravatar_id=#{Digest::MD5.hexdigest(self.email)}&size=64}
  end

  def gravatar?; gravatar_url end

  def avatar
    # Luckily URI::HTTP is a parent of URI::HTTPS so this covers both cases
    return avatar_url if avatar_url && URI.parse(avatar_url.to_s).is_a?(URI::HTTP)
    return gravatar_url if gravatar?
  end

  def avatar?; avatar end

  def display_name
    self.fullname || self.username
  end
end
