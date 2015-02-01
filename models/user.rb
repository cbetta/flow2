require 'digest/md5'
require 'uri'

class User < Sequel::Model
  include Concerns::ErrorsAsArray

  USERNAME_LENGTH_RANGE = (Config[:username_min_length] || 1)..(Config[:username_max_length] || 32)
  EMAIL_LENGTH_RANGE = 6..100

  set_schema do
    primary_key :id
    String :username, index: true, unique: true
    String :email
    String :fullname
    TrueClass :approved, default: false
    String :external_uid, index: true, unique: true
    String :external_token
    String :avatar_url
    Time :created_at
    HStore :metadata

    constraint(:username_length_range, Sequel.function(:char_length, :username) => USERNAME_LENGTH_RANGE)
    constraint(:email_length_range, Sequel.function(:char_length, :email) => EMAIL_LENGTH_RANGE)
  end

  create_table unless table_exists?

  one_to_many :posts
  one_to_many :comments

  def after_initialize
    self.created_at ||= Time.now
    self.metadata ||= Sequel.hstore({})
  end

  def gravatar_url
    return false unless self.email.to_s.length > 5
    %{http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(self.email)}?size=64}
  end

  def gravatar?; gravatar_url end

  def avatar
    # Luckily URI::HTTP is a parent of URI::HTTPS so this covers both cases
    return avatar_url if avatar_url && URI.parse(avatar_url.to_s).is_a?(URI::HTTP)
    return gravatar_url if gravatar?
  end

  def avatar?; avatar end

  def display_name
    if self.fullname && self.fullname.to_s.length > 3
      self.fullname
    elsif self.username
      self.username.sub(/^__/, '')
    else
      "Unknown"
    end
  end

  def social_link
    unless self.username =~ /^__/
      %{ <a href='https://#{AUTH_PROVIDER.downcase}.com/#{self.username}'><i class='fa fa-#{AUTH_PROVIDER.downcase}'></i></a>}
    end
  end

  # Is the user an admin?
  def admin?
    metadata['admin'] && metadata['admin'].to_s == 'true'
  end

  # Make the user an admin - to be used from the console for now
  def admin!
    metadata['admin'] = true
    save
  end

  # Make the user not an admin
  def unadmin!
    metadata['admin'] = false
    save
  end
end
