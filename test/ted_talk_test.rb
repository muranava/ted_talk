require 'minitest/autorun'
require 'ted_talk'

class TestTedTalk < MiniTest::Unit::TestCase
  
  def setup
    @source_url = "http://www.ted.com/talks/ben_saunders_why_bother_leaving_the_house.html"
    @outdir     = File.expand_path(File.dirname(__FILE__)) + "/temp"
    # `rm -rf #{@outdir}` if File.exists? @outdir    
    `mkdir #{@outdir}` unless File.exists? @outdir    
    @tedtalk    = TedTalk::Converter.new(@source_url)
  end
  
  def test_description
    @tedtalk.desc("ja")
  end
  
  def test_execution
    speed = 1
    silence = 2
    language = "ja"
    @tedtalk.execute(@outdir, language, speed, silence)
  end

  def teardown
    # `rm -rf #{@outdir}`
  end

end