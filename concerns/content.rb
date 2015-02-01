module Concerns
	# Common concerns of 'content' models, such as posts and comments
	module Content
		# All content items need created_at set and metadata initializing to an empty hash
  	def after_initialize
	  	self.created_at ||= Time.now
    	self.metadata ||= Sequel.hstore({})
  	end

    def can_be_edited_by?(the_user)
      the_user && (self.user == the_user || the_user.admin?)
    end

  	# UNIX epoch style timestamp
    def timestamp
      self.created_at.to_i
    end

    def author_link
    	self.user && self.user.social_link
    end

  	# The user's avatar's URL, if any
    def avatar_url
      self.user && self.user.avatar
    end
    def avatar?; avatar_url end    # A convenience alias

    # A human readable version of the time (e.g. "Today" or "Last Thursday")
    def time
  	  Kronic.format(self.created_at)
  	end

		# The author's name, if any
  	def author
  	  self.user ? self.user.display_name : self.byline ? self.byline : 'Anon'
  	end

  	# Is the user who owns this 'approved' or an admin?
  	def approved_user?
    	(self.user && self.user.approved) || (self.user && self.user.admin?)
  	end

  	# The day of the year the item was created
  	def day_of_year
    	self.created_at.strftime("%j")
  	end

    # Renders content, renders Markdown, cleans up output HTML, etc.
    def rendered_content
      return '' unless self.content

      content = self.class.expand_plain_links(self.content)

      # Render any Markdown and then sanitize the HTML output
      content = Kramdown::Document.new(content).to_html
      cleaned = Sanitize.fragment(content, elements: self.class::ALLOWED_ELEMENTS, attributes: self.class::ALLOWED_ATTRIBUTES)

      # Change links to have rel='nofollow' (to help with spam) if it's from a non-approved user
      cleaned = self.class.nofollow_links(cleaned) if !self.user || (!self.user.approved && !self.user.admin?)

      cleaned
    end

    def self.included(base); base.extend(ClassMethods) end

    module ClassMethods
      def find_where_editable_by(user, conditions)
        obj = find(conditions)
        return obj if obj.can_be_edited_by?(user)
      end

      def nofollow_links(html)
        doc = Nokogiri::HTML::fragment(html)
        doc.css('a').each { |link| link['rel'] = 'nofollow' }
        doc.to_html
      end

      def expand_plain_links(content)
        # Expand links on their own to being links in Markdown (by surrounding with <>)
        content.gsub(/(^|\s)(https?\:\/\/[^\s\>]*)\.?(?=$|\s)/, '\1<\2>\3')
      end

      # Generate a unique ID (used instead of a number in URLs)
      def generate_unique_id(length = nil)
        length = self::UID_LENGTH unless length
        max = 36 ** length - 1        # e.g. "zzzzzz" in base 36
        min = 36 ** (length - 1)      # e.g. "100000" in base 36

        20.times do
          # Generates a random number that when converted to base 36 will be between "100000" and "zzzzzz"
          uid = (SecureRandom.random_number(max - min) + min).to_s(36)

          # Returns the new ID if no other post has it
          return uid unless find(uid: uid)
        end
      end
    end
  end
end
