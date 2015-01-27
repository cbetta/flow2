class Sanitize
	def self.nofollow_links(html)
		doc = Nokogiri::HTML::fragment(html)
    doc.css('a').each { |link| link['rel'] = 'nofollow' }
    doc.to_html
  end
end
