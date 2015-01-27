module Concerns
	# Common concerns of 'content' models, such as posts and comments
	module Content
		# All content items need created_at set and metadata initializing to an empty hash
  	def after_initialize
	  	self.created_at ||= Time.now
    	self.metadata ||= Sequel.hstore({})
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
  end
end
