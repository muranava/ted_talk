#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'ted_talk/version'
require 'progressbar'
require 'net/http'
require 'json'
require 'taglib'
require 'nokogiri'
require 'digest/md5'

INTRO_DURATION = 16500
AD_DURATION = 4000
POST_AD_DURATION = 2000
ADJUST = 500
DATA_DIR = File.expand_path(File.dirname(__FILE__)) + "/../data"
CACHE_DIR = File.expand_path(File.dirname(__FILE__)) + "/../cache"

Dir.mkdir(DATA_DIR) unless File.exists?(DATA_DIR)
Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)

module TedTalk
class Converter
  
  def initialize(url, outdir = "./")
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
    # @url = data.attribute("data-url").value
    @video_url = ted_doc.xpath("//a[@id='no-flash-video-download']").attribute("href").value
    # @video_url = get_video_urls(ted_doc.text)[-1]
    /(.+)(?:\-[^\-]+)?/ =~ File.basename(@video_url, ".*")
    @basename  = $1
    @outdir = File.join(outdir, @ted_id + "-" + @basename)    
    Dir.mkdir(@outdir) unless File.exists?(@outdir)    
    @captions = {}
    @title = ted_doc.xpath("//h1[1]").text.strip rescue ""
    # title = data.attribute("data-title").value    
    @speaker = @title.split(":", 2).first.strip rescue ""
    # speaker = ted_doc.xpath("//div[@class='quote-attribution'][1]/a[1]").attribute("title").value    
    @available_langs = []
    ted_doc.xpath("//select[@id='languageCode'][1]/option").collect do |op|
      v = op.attributes["value"].value.strip
      @available_langs << v if v != ""
    end
    @available_langs.sort!
    @video_filepath = @outdir + "/" + File.basename(@video_url)
    @wav_filepath = @outdir + "/" + @basename + ".wav"    
    @titles = {}
    @titles["en"] = get_title("en")
    @descriptions = {}
    @descriptions["en"] = get_description("en")
    get_captions("en")    
    
  end
  
  def setup_second_lang(lang)
    unless @available_langs.index lang
      puts "Description in #{lang} is not available"
      return false
    end
    @language_hash = list_langs
    @lang = lang 
    if lang != "en"
      @titles[lang] = get_title(lang)
      @descriptions[lang] = get_description(lang)
      @lang_name = @language_hash[@lang]
      get_captions(lang)
    end    
  end
      
  def desc(lang = "en")    
    setup_second_lang(lang)  
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
  
  def execute(silence = 0, lang = "en")
    setup_second_lang(lang)
    get_video unless File.exists?(@video_filepath)
    get_wav unless File.exists?(@wav_filepath) 
    if silence > 0
      split_wav
      merged = merge_wav(silence)
      mp3 = convert_to_mp3(merged)
      `unlink #{merged}`      
    else
      mp3 = convert_to_mp3(@wav_filepath)
    end
    write_info(mp3)    
  end

  def get_title(lang)
    lang_url = "http://www.ted.com/talks/lang/#{lang}/" + @url_basename
    html = get_html(lang_url)
    lang_doc = Nokogiri::HTML(html)
    lang_doc.xpath("//meta[@name='title']").first.attribute("content").value.split("|").first.strip + "\n"
  end
  
  def get_description(lang)
    lang_url = "http://www.ted.com/talks/lang/#{lang}/" + @url_basename
    html = get_html(lang_url)
    lang_doc = Nokogiri::HTML(html)  
    temp = lang_doc.xpath("//meta[@name='description']").first.attribute("content").value.strip
    /\ATED Talks\s*(.+)\z/ =~ temp
    $1 + "\n"
  end
    
  def get_video
    uri = URI(get_final_location(@video_url))
    file = File.new(@video_filepath, "wb")
    file_size = 0
    puts "Downloading video: #{File.basename(@video_filepath)}"
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.request_get(uri.request_uri) do |res|
        file_size = res.read_header["content-length"].to_i 
        bar = ProgressBar.new(File.basename(@video_filepath), file_size)
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
    result = `/usr/local/bin/ffmpeg  -loglevel panic -i #{@video_filepath} -ac 1 -vn -acodec pcm_s16le -ar 44100 #{@wav_filepath}`
  end

  def get_captions(lang = "en")
    unless @available_langs.index(lang)
      puts "Caption in #{lang} is not available"
      return false
    end    
    script_json = get_script(lang)
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
    
  def split_wav
    captions = @captions["en"]
    puts "Splitting WAV to segments"
    num_digits = captions.size.to_s.split(//).size
    
    ##########
    # timings = []
    # captions.each_with_index do |c, index|
    #   timings << start_time = c[:start_time_s]
    # end
    # timings.unshift "00.00.00" unless timings[0] == "00.00.00"
    # end_time = format_time(captions[-1][:start_time] + captions[-1][:duration])
    # timings.push end_time
    # timings.push "EOF"
    # result = `/usr/local/bin/mp3splt -f -O 00.00.25 -o split-@n #{@wav_filepath} #{timings.join(" ")}`
    ##########

    result = `/usr/local/bin/sox #{@wav_filepath}  #{@outdir}/split-.wav silence 0 1 0.3 -32d : newfile : restart`
  end

  def merge_wav(silence = 0)
    silence_filepath = DATA_DIR + "/silence.wav"
    merged_filepath = @outdir + "/" + @basename + "-m.wav"
    temp_filepath = @outdir + "/temp.wav"
    puts "Merging segments back to one WAV file"
    num_digits = @captions["en"].size.to_s.split(//).size
    files = []
    Dir.foreach(@outdir) do |file|
      next unless /^split\-\d+\.wav$/ =~ file
      files << @outdir + "/" + file      
    end
    index = 0
    bar = ProgressBar.new(@basename, files.size)        
    files.sort.each do |filepath|
      length = `/usr/local/bin/soxi -D #{filepath}`.to_f
      index += 1      
      bar.inc(1)
      if index == 1
        File.rename(filepath, merged_filepath)
        next
      end
      blank_part = length > 0.0 ? (silence_filepath + " ")  * silence : ""
      `/usr/local/bin/sox #{merged_filepath} #{filepath} #{blank_part} #{temp_filepath} ; mv #{temp_filepath} #{merged_filepath} ; rm #{filepath}`
    end
    print "\n"
    return merged_filepath    
  end

  def convert_to_mp3(filepath)
    result_mp3 = @outdir + "/" + @basename + ".mp3"
    `/usr/local/bin/ffmpeg -y -loglevel panic -i #{filepath} -acodec mp3 -ab 128k #{result_mp3}`
    puts "Converting WAV to MP3: #{@basename}.mp3"
    result_mp3
  end

  ##### helper methods #####

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
  
  def get_html(url)
    key = Digest::MD5.new.update(url).to_s
    html = ""
    if File.exists?(CACHE_DIR + "/" + key)
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

  def get_final_location(url)
    begin
       Net::HTTP.get_response(URI(url)) do |res|
         location = res["location"]
         return url if location.nil?
         return get_final_location(location)
       end
     rescue
       puts "Not able to connect to the Internet"
       return url
     end
   end
    
  def download_successful?(full_file_path, file_size)
    File.exist?(full_file_path) && File.size(full_file_path) == file_size
  end
  
  def get_video_urls(html)
    videos = html.scan(/http\:\/\/download.ted.com\/talks\/#{@basename}.*?\.mp4/).sort
  end
  
  def write_info(filepath)
    puts "Writing captions to MP3"
    TagLib::MPEG::File.open(filepath) do |mp3|
      tag = mp3.id3v2_tag
      tag.artist = "TED Talk "
      tag.title  = @title + " (with captions in #{@lang_name})"
      tag.genre  = "Talk"
          
      caption_text = @titles["en"]
      caption_text << @titles[@lang]
      caption_text << "--------------------\n"
      caption_text << @descriptions["en"] 
      caption_text << @descriptions[@lang]
      
      @captions["en"].each_with_index do |c, index|
        caption_text << "--------------------\n\n" if c[:start_of_paragraph]
        next if c[:content] == ""
        caption_text << c[:content] + "\n"
        if @lang and @captions[@lang]
          jp_content = @captions[@lang][index][:content] + "\n\n" rescue ""
          caption_text << jp_content
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
  
  def get_script(lang = "en")
    url = "http://www.ted.com/talks/subtitles/id/#{@ted_id}"
    url << "/lang/#{lang}" unless lang == "en"
    out_filepath = @outdir + "/" + @basename + "-" + lang + ".json"    
    begin
      if File.exists?(out_filepath)
        json_text = File.read(out_filepath)
        script = JSON.parse(json_text)
      else
        puts "Downloading captions: #{lang}"    
        script = nil
        json_text = get_html(url)
        script = JSON.parse(json_text) 
        File.open(out_filepath, "w") do |f|
          f.write JSON.pretty_generate script
        end
      end
    rescue => e
      puts "Not able to parse caption data in json"
      exit
    end
    return script
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
  
end # of class
end # of module

