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
  end
end
