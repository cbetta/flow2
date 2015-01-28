class Comment < Sequel::Model
  include Concerns::Content
  include Concerns::Validations

  CONTENT_LENGTH_RANGE = 5..8192
  INLINE_MAX_LENGTH = 80
  ALLOWED_ELEMENTS = %w{a em strong b br li ul ol p code tt samp pre img}

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

  # Content to show 'inline' on the front page - keep it short and truncate where necessary
  def inline_content
    content = Sanitize.fragment(rendered_content)[0,INLINE_MAX_LENGTH]
    content += "&hellip;" if rendered_content.length > INLINE_MAX_LENGTH
    content
  end

  # The comment's content rendered from Markdown through to HTML and sanitized
  def rendered_content
    content = self.content

    # Expand links on their own to being links in Markdown (by surrounding with <>)
    content.gsub!(/(^|\s)(https?\:\/\/[^\s\>]*)($|\s)/, '\1<\2>\3')

    # Render any Markdown and then sanitize the HTML output
    content = Kramdown::Document.new(content).to_html
    cleaned = Sanitize.fragment(content, elements: ALLOWED_ELEMENTS, attributes: { 'a' => %w{href title} })

    # Change links to have rel='nofollow' (to help with spam) if it's from a non-approved user
    cleaned = Sanitize.nofollow_links(cleaned) if !self.user || (!self.user.approved && !self.user.admin?)

    cleaned
  end

  def validate
    super

    presence_of :content
    length_of :content, in: CONTENT_LENGTH_RANGE
  end
end
