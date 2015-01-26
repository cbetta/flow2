require 'sqlite3'

module Flow
  module Import
    module_function

    def import(file)
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
      $db.execute("SELECT * FROM users ORDER BY id ASC") do |row|
        i += 1
        puts i if i % 100 == 0
        u = User.new
        u.username = row['login']
        u.email = row['email']
        u.set_metadata url: row['url'], crypted_password: row['crypted_password'], salt: row['salt']
        u.set_metadata admin: true if row['admin'] == 1
        u.approved = row['approved_for_feed'] == 1
        u.save
        u.created_at = row['created_at']
        u.save
        $users[row['id']] = u
      end
    end

    def import_posts
      puts "Importing posts"
      i = 0
      $db.execute("SELECT * FROM items ORDER BY id ASC") do |row|
        i += 1
        puts i if i % 100 == 0

        # id title content user_id created_at byline
        p = Post.new
        p.uid = row['id']
        p.title = row['title']

        if row['user_id']
          p.user = $users[row['user_id']]
        else
          p.byline = row['byline']
        end

        p.content = row['content']
        p.save
        p.created_at = row['created_at']
        p.save
        $posts[row['id']] = p
      end
    end

    def import_comments
      puts "Importing comments"
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
        c.save
        c.created_at = row['created_at']
        c.save
      end
    end
  end
end
