#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "progressbar"

$:.unshift File.expand_path(File.dirname(__FILE__))
require 'unix_tools'

module DownloadUtils
  def get_html(url, without_cache = false)
    url = get_final_location(url)
    key = Digest::MD5.new.update(url).to_s
    html = ""
    if File.exists?(CACHE_DIR + "/" + key) and !without_cache
      html = File.read(CACHE_DIR + "/" + key)
    else
      begin
        uri = URI(url)
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
    url = get_final_location(url)
    key = Digest::MD5.new.update(url).to_s
    script = nil
    if File.exists?(CACHE_DIR + "/" + key) and !without_cache
      json_text = File.read(CACHE_DIR + "/" + key)
      script = JSON.parse(json_text)
    else
      begin
        uri = URI(url)
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

  def get_binary(url, without_cache = false)
    url = get_final_location(url)
    basename = File.basename(url)
    filepath = CACHE_DIR + "/" + basename
    return filepath if File.exists? filepath
    file = File.new(filepath, "wb")
    file_size = 0
    uri = URI(url)
    puts "Downloading file: " + basename
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.request_get(uri.request_uri) do |res|
        file_size = res.read_header["content-length"].to_i 
        bar = ProgressBar.new(basename, file_size)
        bar.file_transfer_mode
        res.read_body do |segment|
          bar.inc(segment.size)
          file.write(segment)
        end
      end
    end
    file.close
    print "\n"    
    download_successful?(filepath, file_size) ? filepath : false
  end

  def get_wav(video_filepath)
    ffmpeg = UnixTools::check_command(FFMPEG) 
    basename = File.basename(video_filepath, ".*")
    filepath = CACHE_DIR + "/" + basename + ".wav"
    return filepath if File.exists? filepath
    puts "Converting to audio: #{basename}.wav"      
    `#{ffmpeg} -loglevel panic -i #{video_filepath} -ac 1 -vn -acodec pcm_s16le -ar 44100 #{filepath}`
    return filepath
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
  module_function :get_json
  module_function :get_binary
  module_function :get_wav
  module_function :get_final_location
  module_function :download_successful?
end