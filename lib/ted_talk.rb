#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$:.unshift "~/Dropbox/code/speak_slow/lib"

require 'ted_talk/version'
require 'speak_slow'
require 'json'
require 'net/http'
require 'digest/md5'
require 'rubygems'
require 'progressbar'
require 'taglib'
require 'nokogiri'

FFMPEG = "/usr/local/bin/ffmpeg"

CACHE_DIR = File.expand_path(File.dirname(__FILE__)) + "/../cache"

INTRO_DURATION = 16500
AD_DURATION = 4000
POST_AD_DURATION = 2000

Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)

module WebUtils
  def get_html(url, without_cache = false)
    key = Digest::MD5.new.update(url).to_s
    html = ""
    if File.exists?(CACHE_DIR + "/" + key) and !without_cache
      html = File.read(CACHE_DIR + "/" + key)
    else
      begin
        uri = URI(get_final_location(url))
        res = Net::HTTP.get_response(uri)
        if res.is_a?(Net::HTTPSuccess)
          html = res.body
        else
          puts "HTML download error"
          exit
        end
        File.open(CACHE_DIR + "/" + key, "w") do |f|
          f.write html
        end
      rescue => e
        puts "Not able to download HTML"
        exit
      end
    end
    return html    
  end

  def get_json(url, without_cache = false)
    key = Digest::MD5.new.update(url).to_s
    script = nil
    if File.exists?(CACHE_DIR + "/" + key) and !without_cache
      json_text = File.read(CACHE_DIR + "/" + key)
      script = JSON.parse(json_text)
    else
      begin
        uri = URI(get_final_location(url))
        res = Net::HTTP.get_response(uri)
        json_text = res.body
        script = JSON.parse(json_text) 
        File.open(CACHE_DIR + "/" + key, "w") do |f|
          f.write JSON.pretty_generate script
        end
      rescue => e
        puts "Not able to download HTML"
        exit
      end
    end
    return script
  end

  def get_final_location(url)
    begin
      Net::HTTP.get_response(URI(url)) do |res|
        location = res["location"]
        return url if location.nil?
        return get_final_location(location)
      end
    rescue => e
      puts "Not able to reach at the final location"
      return url
    end
  end
    
  def download_successful?(full_file_path, file_size)
    File.exist?(full_file_path) && File.size(full_file_path) == file_size
  end  

  module_function :get_html
  module_function :get_final_location
  module_function :download_successful?
end

module TedTalk  
  
  def self.desc_talks_rss(lang, num = 12)
    if lang != "en"
      html = WebUtils.get_html("http://www.ted.com/translate/languages/#{lang}", true)
      html_doc = Nokogiri::HTML(html)  
      puts "--------------------------------------------------"  
      html_doc.xpath("//div[@id='list']//dd//a[1]").each do |link|
        puts link.attribute("title")
        puts link.attribute("href").text.sub(/\A\//, "http://www.ted.com/")
        puts "--------------------------------------------------"  
      end
    else
      rss_html = WebUtils.get_html("http://feeds.feedburner.com/tedtalks_video", true)
      rss_doc = Nokogiri::XML(rss_html)  
      talks = rss_doc.xpath("//item")
      puts "--------------------------------------------------"  
      talks.each_with_index do |talk, index|      
        puts title = talk.xpath("title").text
        puts pubdate = talk.xpath("pubDate").text
        puts category = talk.xpath("category").text      
        # puts source_url = WebUtils.get_final_location(talk.xpath("link").text).sub(/\?.+\z/, "")
        puts source_url = talk.xpath("feedburner:origLink").text
        puts description = talk.xpath("description").text      
        puts "--------------------------------------------------"  
        break if index + 1 == num
      end
    end
  end  

  class Converter
    include WebUtils
        
    def initialize(url)
      begin        
        if /(?:http\:\/\/)?(?:www\.)?ted\.com\/talks\/(?:lang\/[^\/]+\/)?(.+\.html)/ =~ url
          @url = "http://www.ted.com/talks/" + $1
        else
          puts "The specified URL does not seem to be a valid one"
          exit
        end
        if html = get_html(@url)
          @html = html
        else
          puts "The specified URL does not respond with a TED Talk content"
          exit
        end
        @url_basename = File.basename(@url)
        ted_doc = Nokogiri::HTML(@html)  
        data = ted_doc.xpath("//div[@id='share_and_save']").first
        @ted_id = data.attribute("data-id").value
        @video_url = ted_doc.xpath("//a[@id='no-flash-video-download']").attribute("href").value
        @basename = File.basename(@video_url, ".*")
        @captions = {}
        @title = ted_doc.xpath("//h1[1]").text.strip rescue ""
        @speaker = @title.split(":", 2).first.strip rescue ""
        @available_langs = []
        ted_doc.xpath("//select[@id='languageCode'][1]/option").collect do |op|
          v = op.attributes["value"].value.strip
          @available_langs << v if v != ""
        end
        @available_langs.sort!
        @titles = {}
        @titles["en"] = get_title("en")
        @descriptions = {}
        @descriptions["en"] = get_description("en")
        @language_hash = list_langs        
      rescue => e
        puts "The specified URL does not seem to contain a regular TED Talk contents"
        exit
      end
    end
  
    def setup_lang(lang)
      unless @available_langs.index lang
        puts "Description in #{lang} is not available"
        return false
      end
      @lang = lang 
      if lang != "en"
        @titles[lang] = get_title(lang)
        @descriptions[lang] = get_description(lang)
        @lang_name = @language_hash[@lang]
      end    
    end
      
    def desc_talk(lang = "en") 
      setup_lang(lang)  
      unless @descriptions[lang]
        lang = "en"
      end
      puts "\nTitle:\n" + @titles["en"]    
      puts @titles[lang] if lang != "en"
      puts ""
      puts "Description:\n" + @descriptions[lang]
      puts ""
      puts "Available Languages: "
      @available_langs.each do |lang_code|
        lang_name = @language_hash[lang_code]
        puts "  " + lang_name + ": " + lang_code
      end
    end
  
    def execute(outdir = "./", lang = "en", speed = 1, silence = 0)
      puts "TedTalk is prepararing for the process"
      @outdir = File.join(outdir, @ted_id + "-" + @basename)    
      Dir.mkdir(@outdir) unless File.exists?(@outdir)    
      @video_filepath = @outdir + "/" + File.basename(@video_url)
      @wav_filepath = @outdir + "/" + @basename + ".wav"    
      
      @ffmpeg = check_command(FFMPEG) 
      @speed = speed
      @silence = silence
      @lang = lang   
      get_captions("en")      
      setup_lang(lang)
      get_captions(lang)      
      get_video unless File.exists?(@video_filepath)
      get_wav unless File.exists?(@wav_filepath)
      outfile = @outdir + "/" + @basename + "-result.mp3"
      speakslow = SpeakSlow::Converter.new(@wav_filepath, outfile)
      speakslow.execute(speed, silence)
      write_info(outfile)    
    end

    def get_title(lang)
      lang_url = "http://www.ted.com/talks/lang/#{lang}/" + @url_basename
      html = get_html(lang_url)
      lang_doc = Nokogiri::HTML(html)
      lang_doc.xpath("//meta[@name='title']").first.attribute("content").value.split("|").first.strip rescue ""
    end
  
    def get_description(lang)
      lang_url = "http://www.ted.com/talks/lang/#{lang}/" + @url_basename
      html = get_html(lang_url)
      lang_doc = Nokogiri::HTML(html)  
      temp = lang_doc.xpath("//meta[@name='description']").first.attribute("content").value.strip
      /\ATED Talks\s*(.+)\z/ =~ temp
      $1 rescue temp ""
    end
    
    def get_video
      uri = URI(get_final_location(@video_url))
      file = File.new(@video_filepath, "wb")
      file_size = 0
      puts "Downloading video: #{File.basename(@video_filepath)}"
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.request_get(uri.request_uri) do |res|
          file_size = res.read_header["content-length"].to_i 
          bar = ProgressBar.new(@basename, file_size)
          bar.file_transfer_mode
          res.read_body do |segment|
            bar.inc(segment.size)
            file.write(segment)
          end
        end
      end
      file.close
      print "\n"    
      download_successful?(@video_filepath, file_size) ? @video_filepath : false
    end
    
    def get_wav
      puts "Converting to audio: #{@basename}.wav"      
      `#{@ffmpeg} -loglevel panic -i #{@video_filepath} -ac 1 -vn -acodec pcm_s16le -ar 44100 #{@wav_filepath}`
    end

    def get_captions(lang = "en")
      unless @available_langs.index(lang)
        puts "Caption in #{lang} is not available"
        return false
      end    
      json_url = "http://www.ted.com/talks/subtitles/id/#{@ted_id}"
      json_url << "/lang/#{lang}" unless lang == "en"
      script_json = get_json(json_url)
      num_total_captions = script_json["captions"].size
      num_digits = num_total_captions.to_s.split(//).size
      captions = [{:id => sprintf("%0#{num_digits}d", 0),
        :start_time_s => "00.00.00", 
        :duration => nil, 
        :content => "", 
        :start_of_paragraph => false, 
        :start_time => 0
        }]
      script_json["captions"].each_with_index do |caption, index|
        result = {}
        result[:id] = sprintf("%0#{num_digits}d", index + 1)
        result[:start_time] = INTRO_DURATION - AD_DURATION + POST_AD_DURATION + caption["startTime"].to_i
        result[:start_time_s] = format_time(result[:start_time])
        result[:duration] = caption["duration"].to_i
        result[:content]  = caption["content"].gsub(/\s+/, " ")
        result[:end_time_s] = format_time(result[:start_time] + caption["duration"].to_i)
        result[:start_of_paragraph] = caption["startOfParagraph"]
        if index == 0
          intro_duration = 
          captions[0][:duration] = result[:start_time]
        end
        captions << result
      end  
      lang_sym = lang
      File.open(@outdir + "/" + @basename + "-" + lang + ".txt", "w") do |f|
        f.write format_captions(captions)
      end
      @captions[lang_sym] = captions
      return captions
    end
    
    def list_langs
      language_hash = {}
      lang_url = "http://www.ted.com/translate/languages"
      html = get_html(lang_url)
      ted_doc = Nokogiri::HTML(html)  
      data = ted_doc.xpath("//div[@id='content'][1]//ul//a").each do |lang|
        lang_name = lang.text
        lang_code = lang.attribute("href").value.split("/")[-1].strip
        language_hash[lang_code] = lang_name.sub(/\(.+?\)/){""}.strip
      end
      return language_hash
    end
    
    def write_info(filepath)
      puts "Writing captions to MP3"
      TagLib::MPEG::File.open(filepath) do |mp3|
        tag = mp3.id3v2_tag
        tag.artist = "TED Talk "
        tag.title  = @title
        tag.title  += " (with captions in #{@lang_name})" if @lang_name
        tag.title  += " [x#{@speed}]" if @speed and  @speed != 1
        tag.genre  = "Talk"
          
        caption_text = @titles["en"] + "\n"
        caption_text << @titles[@lang] + "\n" if @titles[@lang]
        caption_text << "--------------------\n"
        caption_text << @descriptions["en"] + "\n"
        caption_text << @descriptions[@lang] if @titles[@lang] + "\n"
        caption_text << "\n"
        @captions["en"].each_with_index do |c, index|
          caption_text << "--------------------\n\n" if c[:start_of_paragraph]
          next if c[:content] == ""
          caption_text << c[:content] + "\n"
          if @captions[@lang]
            bl_content = @captions[@lang][index][:content] + "\n\n" rescue ""
            caption_text << bl_content
          end
        end
  
        uslt = TagLib::ID3v2::UnsynchronizedLyricsFrame.new
        uslt.language = "eng"
        uslt.text_encoding = TagLib::String::UTF8
        uslt.text = caption_text
  
        tag.add_frame(uslt)
        mp3.save
      end
    end
  
  
    def format_captions(captions)
      lang_name = @lang_name || "English"
      result =  "TED Talk ID: #{@ted_id}\n"
      result << "Speaker: #{@speaker}\n"
      result << "Title: #{@title} (with captions in #{lang_name})\n"
      result << "URL: #{@url}\n\n"
      num_digits = captions.size.to_s.split(//).size
      captions.each_with_index do |c, index|
        index_s = sprintf("%0#{num_digits}d", index + 1)        
        result << "\n" if c[:start_of_paragraph]
        result << "#{index_s}  #{c[:start_time_s]}  #{c[:content]} \n"
      end
      return result
    end
  
    def format_time(time)
      millis = time % 1000 / 10
      millis_s  = sprintf("%02d", millis)        
      total_seconds = time / 1000
      minutes = total_seconds / 60    
      seconds = total_seconds - minutes * 60
      seconds_s  = sprintf("%02d", seconds)    
      minutes_s = sprintf("%02d", minutes)
      minutes_s = sprintf("%02d", minutes)
      minutes_s + "." + seconds_s + "." + millis_s
    end

    def delete_dir(directory_path)
      if FileTest.directory?(directory_path)
        Dir.foreach(directory_path) do |file|
          next if /^\.+$/ =~ file
          delete_dir(directory_path.sub(/\/+$/,"") + "/" + file )
        end
        Dir.rmdir(directory_path) rescue ""
      else
        File.delete(directory_path) rescue ""
      end
    end  

    def get_video_urls(html)
      videos = html.scan(/http\:\/\/download.ted.com\/talks\/#{@basename}.*?\.mp4/).sort
    end
    
    def check_command(command)
      basename = File.basename(command)
      path = ""
      print "Checking #{basename} command: "
      if open("| which #{command} 2>/dev/null"){ |f| path = f.gets }
        puts "detected at #{path}"
        return path.strip
      elsif open("| which #{basename} 2>/dev/null"){ |f| path = f.gets }
        puts "detected at #{path}"
        return path.strip
      else
        puts "not installed to the system"
        exit
      end
    end

  end # of class
end # of module

