class Post < Sequel::Model
  include Concerns::Content
  include Concerns::Validations

  CONTENT_LENGTH_RANGE = 10..10000
  TITLE_LENGTH_RANGE = 6..100
  POSTS_PER_PAGE = ENV['POSTS_PER_PAGE'] || 25
  ALLOWED_ELEMENTS = %w{a em strong b br li ul ol p code tt samp pre}
  ALLOWED_ATTRIBUTES = { 'a' => %w{href title} }

  set_schema do
    primary_key :id
    String :uid, index: true, unique: true
    String :slug
    String :title
    String :content, text: true
    String :byline
    TrueClass :visible, default: true
    Time :created_at
    HStore :metadata

    foreign_key :user_id, :users, on_delete: :set_null, on_update: :cascade

    constraint(:title_length_range, Sequel.function(:char_length, :title) => TITLE_LENGTH_RANGE)
    constraint(:content_length_range, Sequel.function(:char_length, :content) => CONTENT_LENGTH_RANGE)
  end

  unless table_exists?
    create_table
  end

  many_to_one :user
  one_to_many :comments

    # Are there enough posts to have a page 2, 3, 4, etc?
  def self.is_there_a_page?(page)
    Post.count > (page - 1) * POSTS_PER_PAGE
  end

  # Return all recent visible items in reverse ID order
  def self.recent_from_offset(offset = 0)
    where(visible: true).reverse_order(:id).limit(POSTS_PER_PAGE).offset(offset)
  end

  # Generate a unique ID (used instead of a number in URLs)
  def self.generate_unique_id(length = 6)
    max = 36 ** length - 1        # e.g. "zzzzzz" in base 36
    min = 36 ** (length - 1)      # e.g. "100000" in base 36

    20.times do
      # Generates a random number that when converted to base 36 will be between "100000" and "zzzzzz"
      uid = (SecureRandom.random_number(max - min) + min).to_s(36)

      # Returns the new ID if no other post has it
      return uid unless find(uid: uid)
    end
  end


  # Make sure every post has a unique ID (used in URLs)
  def after_initialize
    super
    self.uid ||= self.class.generate_unique_id
  end

  # The post's URL relative to the base URL
  def url
    "/p/" + self.uid + "-" + self.rendered_slug
  end

  # Break up the content into logical parts
  def content_parts
    content = rendered_content.dup

    # If formed of paragraphs or DIVs, get the first one
    if content =~ /\<(p|div)\>/i
      content = Nokogiri::HTML(content).css($1)
    else
      # Otherwise, allow anything up until a forced newline
      content = content.split(/\<br|\n\n|\r\n\r\n/i)
    end
  end

  # The first paragraph or 'chunk' of the body, as suitable for a front page or abbreviated feed
  def lead_content
    content = content_parts.first.to_s

    # Tighter restrictions on front page excerpts than elsewhere
    content = Sanitize.fragment(content, elements: %w{a em strong b code}, attributes: ALLOWED_ATTRIBUTES)

    # Change links to have rel='nofollow' (to help with spam) if it's from a non-approved user
    content = Sanitize.nofollow_links(content) if !self.user || (!self.user.approved && !self.user.admin?)
      
    content
  end

  def more_inside?
    content_parts.length > 1
  end

  # A description for meta tag use
  def description
    Sanitize.fragment(lead_content).gsub(/[^A-Za-z0-9 '-.,?_+"]/, '').gsub(/\s+/, ' ').strip
  end

  # The post's content rendered from Markdown through to HTML and sanitized
  def rendered_content
    return '' unless self.content
    content = self.content

    # Expand links on their own to being links in Markdown (by surrounding with <>)
    content.gsub!(/(^|\s)(https?\:\/\/[^\s\>]*)($|\s)/, '\1<\2>\3')

    content = Kramdown::Document.new(content).to_html
    cleaned = Sanitize.fragment(content, elements: ALLOWED_ELEMENTS, attributes: ALLOWED_ATTRIBUTES)

    # Change links to have rel='nofollow' (to help with spam) if it's from a non-approved user
    cleaned = Sanitize.nofollow_links(cleaned) if !self.user || (!self.user.approved && !self.user.admin?)

    cleaned
  end

  # Does this post have any comments on it?
  def comments?
    self.comments && !self.comments.empty?
  end

  # Get or set the 'slug' that appears on the end of post URLs
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

    presence_of :content
    length_of :content, in: CONTENT_LENGTH_RANGE

    # If it's not an approved user, the post needs to contain at least one link
    unless self.approved_user? || self.rendered_content =~ /\<a /i
      errors.add(:content, 'Your post contains no links')
    end

    presence_of :title
    length_of :title, in: TITLE_LENGTH_RANGE
  end
end
