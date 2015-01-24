require 'sqlite3'

module Flow
  module Import
    module_function

    def import(file)

      $db = SQLite3::Database.new file
      $db.results_as_hash = true
      import_posts
    end

    def import_posts
      puts "Importing posts"
      $db.execute("SELECT * FROM items ORDER BY id DESC LIMIT 10") do |row|
        # id title content user_id created_at byline
        p = Post.new
        p.uid = row['id']
        p.title = row['title']
        p.created_at = row['created_at']
        p.byline = row['byline']
        p.content = row['content']
        p.save
      end
    end
  end
end
