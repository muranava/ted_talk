require 'minitest/autorun'
require 'ted_talk'

class TestTedTalk < MiniTest::Unit::TestCase
  
  def setup
    @source_url = "http://www.ted.com/talks/steven_addis_a_father_daughter_bond_one_photo_at_a_time.html"
    @outdir     = File.expand_path(File.dirname(__FILE__)) + "/temp"
    `rm -rf #{@outdir}` if File.exists? @outdir    
    `mkdir #{@outdir}` 
    @silence    = 2
    @tedtalk    = TedTalk::Converter.new(@source_url, @outdir)
  end
  
  def test_description
    @tedtalk.desc("ja")
  end
  
  def test_execution
    silence = 2
    language = "zh-tw"
    @tedtalk.execute(silence, language)
  end

  def teardown
    `rm -rf #{@outdir}`
  end

  # def test_for_helvetica_font
  #   assert_equal "helvetica!", @hipster.preferred_font
  # end
  # 
  # def test_not_mainstream
  #   refute @hipster.mainstream?
  # end
end