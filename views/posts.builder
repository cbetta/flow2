xml.instruct! :xml, :version => "1.0" 
xml.rss :version => "2.0" do
  xml.channel do
    xml.title ENV['SITE_NAME']
    xml.description ENV['SITE_DESCRIPTION']
    xml.link ENV['BASE_URL']

    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.description post.lead_content
        xml.pubDate post.created_at.rfc2822
        xml.link ENV['BASE_URL'] + post.url
        xml.guid ENV['BASE_URL'] + post.url
      end
    end
  end
end
