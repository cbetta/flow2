class Comment < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :content
  attribute :byline
  reference :post, :Post
  reference :user, :User
  attribute :created_at, Type::Time
  attribute :metadata, Type::Hash

  MIN_LENGTH = 10
  MAX_LENGTH = 4096

  def before_create
    self.created_at ||= Time.now
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
    cleaned = Sanitize.fragment(content, elements: COMMENT_ELEMENTS, attributes: { 'a' => %w{href title} })

    if !self.user || !self.user.approved
      doc = Nokogiri::HTML::fragment(cleaned)
      doc.css('a').each { |link| link['rel'] = 'nofollow' }
      cleaned = doc.to_html
    end

    return cleaned
  end

  def avatar?; avatar_url end

  def time
    Kronic.format(self.created_at)
  end

  def author
    self.user ? self.user.username : self.byline ? self.byline : 'Anon'
  end

  def valid?
    if self.content
      errors << ['content', "Your comment is too short (#{MIN_LENGTH} chars min)"] if self.content.to_s.length < MIN_LENGTH
      errors << ['content', "Your comment is too long (#{MAX_LENGTH} chars max)"] if self.content.to_s.length > MAX_LENGTH
    else
      errors << ['content', "No post body present"]
    end

    errors.length == 0
  end

  def errors
    @errors ||= []
  end
end
