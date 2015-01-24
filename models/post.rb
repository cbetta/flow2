class Post < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :uid
  index :uid
  attribute :slug
  attribute :title
  attribute :content
  reference :user, :User
  collection :comments, :Comment
  attribute :byline
  attribute :created_at, Type::Time
  attribute :metadata, Type::Hash

  def before_create
    self.created_at = Time.now
  end

  def timestamp
    self.created_at.to_i
  end

  def time
    self.created_at.strftime("%B %e %Y")
  end

  def author
    self.user ? self.user.username : self.byline ? self.byline : 'Anon'
  end

  def avatar
    return "http://www.gravatar.com/avatar.php?gravatar_id=8e2b996de3842c6ef7e68a82fa5f01f5&size=54"
    self.user && self.user.avatar
  end

  def url
    "/p/" + self.uid + "-" + self.rendered_slug
  end

  def rendered_slug
    return self.slug if self.slug

    self.slug = self.title
                    .downcase
                    .gsub(/\P{ASCII}/, '')
                    .gsub(/\s+/, '-')
                    .gsub(/[^a-z0-9\-]/, '')[0,60]
    self.save

    return self.slug
  rescue
    ''
  end
end
