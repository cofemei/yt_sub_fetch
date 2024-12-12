require "minitest/autorun"
require_relative "test_helper"

class YouTubeSubtitleFetchTest < Minitest::Test
  def test_parse_options_from_cli
    args = ["-u", "https://www.youtube.com/watch?v=testvideo", "-L"]
    options = YtSubFetch::YouTubeSubtitleFetch.parse_options_from_cli(args)

    assert_equal "https://www.youtube.com/watch?v=testvideo", options[:url]
    assert options[:list]
    refute options[:all_languages]
    assert_nil options[:language]
    refute options[:debug]
  end

  def test_extract_video_id
    url = "https://www.youtube.com/watch?v=0oNX_BHgi32"
    video_id = YtSubFetch::YouTubeSubtitleFetch.new({url: url}).extract_video_id(url)

    assert_equal "0oNX_BHgi32", video_id
  end
end
