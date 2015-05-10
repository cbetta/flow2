class Comment < Sequel::Model
  include Concerns::Content
  include Concerns::Validations
  include Concerns::ErrorsAsArray

  CONTENT_LENGTH_RANGE = 5..(Config[:comment_max_length] || 8192)
  INLINE_MAX_LENGTH = Config[:comment_inline_max_length] || 80
  ALLOWED_ELEMENTS = Config[:comment_allowed_elements] || %w{a em strong b br li ul ol p code tt samp pre img}
  ALLOWED_ATTRIBUTES = { 'a' => %w{href title} }

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

  def validate
    super

    BLACKLIST.each do |blacklisted|
      if self.rendered_content.downcase.include?(blacklisted)
        errors.add(:content, 'Your post contained blacklisted content')
        break
      end
    end

    presence_of :content
    length_of :content, in: CONTENT_LENGTH_RANGE
  end
end
