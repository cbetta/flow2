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

  MIN_LENGTH = 10
  MAX_LENGTH = 10000


  def before_create
    self.created_at ||= Time.now
    self.metadata ||= {}
    self.uid ||= self.class.generate_unique_id
  end

  def self.generate_unique_id(length = 6)
    max = 36 ** length - 1        # e.g. "zzzzzz" in base 36
    min = 36 ** (length - 1)      # e.g. "100000" in base 36

    loop do
      uid = (SecureRandom.random_number(max - min) + min).to_s(36)
      return uid unless find(uid: uid).first
    end
  end

  def timestamp
    self.created_at.to_i
  end

  def time
    Kronic.format(self.created_at)
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

    cleaned = Sanitize.fragment(content, elements: %w{a em strong b}, attributes: { 'a' => %w{href title} })

    if !self.user || !self.user.approved
      doc = Nokogiri::HTML::fragment(cleaned)
      doc.css('a').each { |link| link['rel'] = 'nofollow' }
      cleaned = doc.to_html
    end

    return cleaned
  end

  def approved_user?
    self.user && self.user.approved
  end

  def truncated?
    content = rendered_content.dup

    if content =~ /\<(p|div)\>/i
      return true if Nokogiri::HTML(content).css($1).length > 1
    else
      return true if content.split(/\<br|\n\n|\r\n\r\n/i).length > 1
    end

    return false
  end

  def description
    Sanitize.fragment(lead_content).gsub(/[^A-Za-z0-9 '-.,?_+"]/, '').gsub(/\s+/, ' ').strip
  end

  def rendered_content
    return '' unless self.content
    content = Kramdown::Document.new(self.content).to_html
    Sanitize.fragment(content, elements: POST_ELEMENTS, attributes: { 'a' => %w{href title} })
  end

  def comments?
    self.comments && !self.comments.empty?
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

  def valid?
    if self.content
      errors << ['content', "Post is too short (#{MIN_LENGTH} chars min)"] if self.content.to_s.length < MIN_LENGTH
      errors << ['content', "Post is too long (#{MAX_LENGTH} chars max)"] if self.content.to_s.length > MAX_LENGTH
      errors << ['content', "Post doesn't contain any links"] if self.rendered_content !~ /<a /i
    else
      errors << ['content', "No post body present"]
    end

    if self.title
      errors << ['title', "Title is too short"] if self.title.to_s.length < 6
      errors << ['title', "Title is too long"] if self.title.to_s.length > 85
    else
      errors << ['title', "No title present"]
    end

    errors.length == 0
  end

  def errors
    @errors ||= []
  end
end
