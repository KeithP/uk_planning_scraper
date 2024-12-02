require 'mechanize'
require 'pp'

module UKPlanningScraper
  class Authority
    private
    def scrape_richmond(params, options)
      puts "Using Richmond scraper."
      
      apps = []

      agent = Mechanize.new{ |a| a.ssl_version, a.verify_mode = 'TLSv1_2', OpenSSL::SSL::VERIFY_NONE }
      puts "Getting: #{@url}"
      page = agent.get(@url) # load the search form page

      # Check that the search form is actually present.
      # When Idox has an internal error it returns an error page with HTTP 200.
      unless form = page.form('aspnetForm')  
        puts "Error: Search form page failed to load."
        return []
      end

      date_format = "%d/%m/%Y"
      form.send(:"ctl00$PageContent$dpValFrom", params[:validated_from].strftime(date_format)) if params[:validated_from]
      form.send(:"ctl00$PageContent$dpValTo", params[:validated_to].strftime(date_format)) if params[:validated_to]
      form.send(:"ctl00$PageContent$ddLimit", 500)

      page = agent.submit(form, form.buttons.first)

      if page.search('.errors').inner_text.match(/Too many results found/i)
        raise TooManySearchResults.new("Scrape in smaller chunks. Use shorter date ranges and/or more search parameters.")
      end      
   
      # Parse search results
      items = page.search('#aspnetForm li')
      puts "Found #{items.size} apps on this page: #{page.uri.to_s}"
	    base_url = page.uri.to_s.match(/(https?:\/\/.+?PlanData2\/)/)[1]

      items.each do |app|
        data = Application.new
        data.scraped_at = Time.now
        data.info_url = base_url + app.at('a')['href']
        data.documents_url = data.info_url
        data.council_reference = app.at('a').inner_text.strip
        data.address = app.at('h3').inner_text.strip
        data.description = app.at('p+ p').inner_text.strip 
        apps << data
      end         
      
      apps
    end 
  end 
end
