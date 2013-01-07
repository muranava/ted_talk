#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$:.unshift File.expand_path(File.dirname(__FILE__))

module UnixTools
  
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

  module_function :check_command  
  module_function :delete_dir
end