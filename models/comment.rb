class Comment < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :content
  attribute :byline
  reference :post, :Post
  reference :user, :User
  attribute :created_at, Type::Time
  attribute :metadata, Type::Hash

  def before_create
    self.created_at = Time.now
    self.metadata ||= {}
  end

  def timestamp
    self.created_at.to_i
  end

  def avatar_url
    self.user && self.user.avatar
  end

  def inline_content
    length = 80
    content = Sanitize.fragment(rendered_content)[0,length]
    content += "..." if rendered_content.length > length
    content
  end

  def rendered_content
    content = Kramdown::Document.new(self.content).to_html
    Sanitize.fragment(content, elements: OKAY_ELEMENTS, attributes: { 'a' => %w{href title} })
  end

  def avatar?; avatar_url end

  def time
    Kronic.format(self.created_at) #.strftime("%B %e %Y")
  end

  def author
    self.user ? self.user.username : self.byline ? self.byline : 'Anon'
  end
end
