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
    self.metadata ||= {}
  end

  def timestamp
    self.created_at.to_i
  end

  def time
    Kronic.format(self.created_at) #.strftime("%B %e %Y")
  end

  def author
    self.user ? self.user.username : self.byline ? self.byline : 'Anon'
  end

  def avatar_url
    self.user && self.user.avatar
  end

  def avatar?; avatar_url end

  def url
    "/p/" + self.uid + "-" + self.rendered_slug
  end

  def lead_content
    content = rendered_content.dup

    # If formed of paragraphs or DIVs, get the first one
    if content =~ /\<(p|div)\>/i
      content = Nokogiri::HTML(content).css($1).first.to_s
    else
      # Otherwise, allow anything up until a forced newline
      content = content.split(/\<br|\n\n|\r\n\r\n/i).first
    end

    Sanitize.fragment(content, elements: %w{a em strong b}, attributes: { 'a' => %w{href title} })
  end

  def description
    Sanitize.fragment(lead_content).gsub(/[^A-Za-z0-9 '-.,?_+"]/, '').gsub(/\s+/, ' ').strip
  end

  def rendered_content
    content = Kramdown::Document.new(self.content).to_html
    Sanitize.fragment(content, elements: OKAY_ELEMENTS, attributes: { 'a' => %w{href title} })
  end

  def rendered_slug
    return self.slug if self.slug

    self.slug = self.title
                    .downcase
                    .gsub(/\P{ASCII}/, '')
                    .gsub(/\s+/, '-')
                    .gsub(/[^a-z0-9\-]/, '')
                    .gsub(/-+/, '-')[0,80]
    self.save

    return self.slug
  rescue
    ''
  end
end
