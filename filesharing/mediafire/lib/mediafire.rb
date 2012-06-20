require 'nokogiri'
require 'curl'
require 'cgi'
require 'v8'

require 'extensions'

module MediaFire
  define_exceptions :LinkError, :Captcha, :NetworkError, :JSError, :ParseError 

  # Download a file from MediaFire to the current directory and return the file path.
  def self.download(url)
    body, headers = catch { Curl.get_with_headers(url) }.
      on(Curl::Err::CurlError => NetworkError.new("Cannot get main page"))
      
    # Validate that it's a MediaFire page with a file to download
    headers["Location"] !~ /error.php/ or
      raise LinkError.new("Invalid or deleted file")
    doc = Nokogiri::HTML(body)
    doc.at_css("#form_captcha").blank? or
      raise Captcha.new("Mediafire returns a reCaptcha after too many connections")
    doc.at_css(".dl_options_innerblock") or
      raise ParseError.new("This does not seem a Mediafire file page", :body => body)
    file_name = doc.at_css(".download_file_title").maybe.text.strip.presence or
      raise ParseError.new("Cannot find file name", :body => body)
    
    # Run obfuscated JS code to get the final file URL
    script = doc.at_css(".dl_startlink script") or
      raise ParseError.new("Cannot find JS element", :body => body)
    js_stubs = "var document = {write: function(x) { return x; }};"
    link = catch { V8::Context.new.eval(js_stubs + script.text) }.
      on(V8::JSError => JSError.new("Error evaling JS", :body => body))
    file_url = Nokogiri::HTML.fragment(link).at_css("a").maybe["href"] or
      raise ParseError.new("Cannot find link in obfuscated JS", :body => body)
      
    catch { Curl.download_to_file(file_url, file_name, :show_progressbar => true) }.
      on(Curl::Err::CurlError => NetworkError.new("Error downloading file"))
  end
end
