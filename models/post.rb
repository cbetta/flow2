class Post < Sequel::Model(DB[:posts])
  CONTENT_LENGTH_RANGE = 10..10000
  TITLE_LENGTH_RANGE = 6..100
  POSTS_PER_PAGE = ENV['POSTS_PER_PAGE'] || 25

  set_schema do
    primary_key :id
    String :uid, index: true, unique: true
    String :slug
    String :title
    String :content, text: true
    String :byline
    Time :created_at
    HStore :metadata

    foreign_key :user_id, :users, on_delete: :set_null, on_update: :cascade

    constraint(:title_length_range, Sequel.function(:char_length, :title) => TITLE_LENGTH_RANGE)
    constraint(:content_length_range, Sequel.function(:char_length, :content) => CONTENT_LENGTH_RANGE)
  end

  create_table unless table_exists?

  many_to_one :user
  one_to_many :comments

  def after_initialize
    self.created_at ||= Time.now
    self.metadata ||= Sequel.hstore({})
    self.uid ||= self.class.generate_unique_id
  end


  def self.generate_unique_id(length = 6)
    max = 36 ** length - 1        # e.g. "zzzzzz" in base 36
    min = 36 ** (length - 1)      # e.g. "100000" in base 36

    loop do
      uid = (SecureRandom.random_number(max - min) + min).to_s(36)
      return uid unless find(uid: uid)
    end
  end

  def timestamp
    self.created_at.to_i
  end

  def time
    Kronic.format(self.created_at)
  end

  def author
    self.user ? self.user.display_name : self.byline ? self.byline : 'Anon'
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

  def validate
    super

    if self.content && self.content.is_a?(String)
      errors.add(:content, 'Post is too short') if self.content.length < CONTENT_LENGTH_RANGE.min
      errors.add(:content, 'Post is too long') if self.content.length > CONTENT_LENGTH_RANGE.max
      errors.add(:content, 'Your post contains no links') if !self.user.admin? && self.content !~ /\<a /i
    else
      errors.add(:content, 'No post body present')
    end

    if self.title && self.title.is_a?(String)
      errors.add(:title, 'Title is too short') if self.title.length < TITLE_LENGTH_RANGE.min
      errors.add(:title, 'Title is too long') if self.title.length > TITLE_LENGTH_RANGE.max
    else
      errors.add(:title, 'Title is not present')
    end
  end

  def self.is_there_a_page?(page)
    Post.count > (page - 1) * POSTS_PER_PAGE
  end
end
