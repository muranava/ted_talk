require 'minitest/autorun'
require 'ted_talk'

class TestTedTalk < MiniTest::Unit::TestCase
  
  def setup
    @source_url = "http://www.ted.com/talks/steven_addis_a_father_daughter_bond_one_photo_at_a_time.html"
    @outdir     = File.expand_path(File.dirname(__FILE__)) + "/temp"
    # `rm -rf #{@outdir}` if File.exists? @outdir    
    `mkdir #{@outdir}` unless File.exists? @outdir    
    @tedtalk    = TedTalk::Converter.new(@source_url)
  end
  
  def test_description
    @tedtalk.desc_talk("ja")
  end
  
  def test_execution
    speed = 0.8
    silence = 3
    language = "ja"
    @tedtalk.execute(@outdir, language, speed, silence)
  end

  def teardown
    # `rm -rf #{@outdir}`
  end

end