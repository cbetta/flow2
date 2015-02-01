require 'sqlite3'

module Flow
  # Import old flow site data from an SQLite3 database
  # Hey, somehow SQLite3 survived in production on rubyflow.com for 6 years! :-)
  # Almost no end users will require this so don't worry about it.
  module Import
    module_function

    def import(file, database_url = nil)
      # Import from the Web
      t = nil
      if file.start_with?('http')
        require 'open-uri'
        t = Tempfile.new('db')
        t.write open(file).read
        file = t.path
      end

      $db = SQLite3::Database.new file
      $db.results_as_hash = true
      $users = {}
      $posts = {}
      import_users
      import_posts
      import_comments

      t.unlink if t
    end

    def import_users
      puts "Import users"
      i = 0
      DB.run("TRUNCATE users CASCADE")
      $db.execute("SELECT * FROM users ORDER BY id ASC") do |row|
        i += 1
        puts i if i % 100 == 0
        u = User.new
        u.username = "__" + row['login']   # append double underscore so 'old' style users are still around, but not conflicting with new ones

        u.email = row['email']
        u.email = nil if u.email && u.email.length < User::EMAIL_LENGTH_RANGE.min

        u.metadata[:url] = row['url']
        u.metadata[:crypted_password] = row['crypted_password']
        u.metadata[:salt] = row['salt']
        u.metadata[:admin] = true if row['admin'] == 1
        u.approved = row['approved_for_feed'] == 1
        u.created_at = row['created_at']
        begin
          u.save
        rescue
          puts "Skipping duplicate user #{u.username}"
        end
        $users[row['id']] = u
      end
    end

    def import_posts
      puts "Importing posts"
      i = 0
      DB.run("TRUNCATE posts CASCADE")
      $db.execute("SELECT * FROM items ORDER BY id ASC") do |row|
        i += 1
        puts i if i % 100 == 0

        # id title content user_id created_at byline
        p = Post.new
        p.uid = row['id']
        p.title = row['title']

        if p.title.to_s.length > Post::TITLE_LENGTH_RANGE.max
          p.title = p.title[0, Post::TITLE_LENGTH_RANGE.max]
        elsif p.title.to_s.length < Post::TITLE_LENGTH_RANGE.min
          p.title += " " * Post::TITLE_LENGTH_RANGE.min
        end

        if row['user_id']
          p.user = $users[row['user_id']]
        else
          p.byline = row['byline']
        end

        p.content = row['content']
        p.created_at = row['created_at']
        begin
          p.save validate: false
        rescue => e
          puts "Skipping post #{p.uid} due to errors"
          p p.errors
          p e
        end
        $posts[row['id']] = p
      end
    end

    def import_comments
      puts "Importing comments"
      DB.run("TRUNCATE comments CASCADE")
      i = 0
      $db.execute("SELECT * FROM comments ORDER BY id ASC") do |row|
        i += 1
        puts i if i % 100 == 0

        c = Comment.new
        c.content = row['content']

        if row['user_id']
          c.user = $users[row['user_id']]
        else
          c.byline = row['byline']
        end

        c.post = $posts[row['item_id']]
        c.created_at = row['created_at']
        begin
          c.save
        rescue
          puts "Skipping comment #{row['id']} due to errors"
        end
      end
    end
  end
end
