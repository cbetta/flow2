class Comment < Sequel::Model(DB[:comments])
  CONTENT_LENGTH_RANGE = 5..8192

  set_schema do
    primary_key :id

    String :content, text: true
    String :byline
    Time :created_at
    TrueClass :visible, default: true
    HStore :metadata

    foreign_key :user_id, :users, on_delete: :set_null, on_update: :cascade
    foreign_key :post_id, :posts, on_delete: :set_null, on_update: :cascade

    constraint(:content_length_range, Sequel.function(:char_length, :content) => CONTENT_LENGTH_RANGE)
  end

  create_table unless table_exists?

  many_to_one :user
  many_to_one :post

  def after_initialize
    self.created_at ||= Time.now
    self.metadata ||= Sequel.hstore({})
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

  def validate
    super

    if self.content && self.content.is_a?(String)
      errors.add(:content, 'Your comment is too short') if self.content.length < CONTENT_LENGTH_RANGE.min
      errors.add(:content, 'Your comment is too long') if self.content.length > CONTENT_LENGTH_RANGE.max
    else
      errors.add(:content, 'No comment body present')
    end
  end
end
