# frozen_string_literal: true

require_relative "yt_sub_fetch/version"
require "optionparser"
require "fileutils"
require "uri"
require "net/http"
require "json"

module YtSubFetch
  class YouTubeSubtitleFetch
    def initialize(options)
      @options = options

      validate_options
      validate_youtube_url(@options[:url])
    end

    def self.parse_options_from_cli(args)
      options = {
        url: nil,
        language: nil,
        all_languages: false,
        list: false,
        debug: false
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: yt_sub_fetch.rb [options] URL"

        opts.on("-u", "--url URL", "YouTube video URL") do |url|
          options[:url] = url
        end

        opts.on("-l", "--language LANG", "Subtitle language code (e.g., en, zh-TW)") do |lang|
          options[:language] = lang
        end

        opts.on("-L", "--list", "List available subtitle languages") do
          options[:list] = true
        end

        opts.on("-a", "--all", "Download all subtitles") do
          options[:all_languages] = true
        end

        opts.on("-d", "--debug", "Enable debug output") do
          options[:debug] = true
        end

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          exit
        end
      end.parse!(args)

      unless options[:url]
        options[:url] = ARGV.last
      end

      options
    end

    def debug_print(message)
      puts "[DEBUG] #{message}" if @options[:debug]
    end

    def validate_options
      raise "YouTube video URL is required" if @options[:url].nil?

      @video_id = extract_video_id(@options[:url])
      debug_print "Video ID: #{@video_id}"
    end

    def validate_youtube_url(url)
      # 支援多種 YouTube URL 格式的正則表達式
      youtube_regex = /^(https?:\/\/)?(www\.)?(youtube\.com\/(watch\?v=|embed\/|v\/)|youtu\.be\/)([^&\s]+)/

      unless url&.match?(youtube_regex)
        puts "Error: Invalid YouTube URL. Please provide a valid YouTube video URL."
        exit 1
      end
    end

    def extract_video_id(url)
      match = url.match(/(?:v=|\/)([0-9A-Za-z_-]{11})/)
      raise "Invalid YouTube URL" unless match
      match[1]
    end

    def download_subtitles
      FileUtils.mkdir_p("subtitles")

      subtitles = fetch_subtitles

      debug_print "Found subtitles: #{subtitles}"

      if subtitles.empty?
        puts "No subtitles found for this video."
        exit 1
      end

      if @options[:list]
        subtitles.each do |s|
          puts "#{s[:language]}(#{s[:name]})"
        end

        exit 1
      end

      if @options[:all_languages]
        download_all_subtitles(subtitles)
      else
        download_specific_language(subtitles)
      end
    end

    def run
      download_subtitles
    rescue => e
      puts "Error: #{e.message}"
      debug_print e.backtrace.join("\n")
      exit 1
    end

    private

    def fetch_subtitles
      url = follow_redirects("https://www.youtube.com/watch?v=#{@video_id}")

      debug_print "Final URL after redirects: #{url}"

      headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
        "Accept-Language" => "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7",
        "Referer" => "https://www.youtube.com/",
        "Cookie" => "CONSENT=YES+srp.gws-20231218+FX+436; GPS=1; VISITOR_INFO1_LIVE=some_random_value"
      }

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(url.path + (url.query ? "?#{url.query}" : ""), headers)

      response = http.request(request)

      debug_print "Response status: #{response.code}"

      # 保存原始響應以檢查
      File.write("youtube_response.html", response.body) if @options[:debug]

      subtitles = extract_subtitles_from_page(response.body)

      if subtitles.empty?
        debug_print "First extraction method failed, trying alternative methods"
        subtitles = extract_subtitles_from_api
      end

      subtitles
    end

    def follow_redirects(initial_url, limit = 5)
      raise "Too many redirects" if limit == 0

      uri = URI(initial_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        uri
      when Net::HTTPRedirection
        debug_print "Redirected to: #{response["location"]}"
        follow_redirects(response["location"], limit - 1)
      else
        uri
      end
    end

    def extract_subtitles_from_page(body)
      subtitles = []

      # 更複雜的正則表達式提取
      patterns = [
        /'caption_tracks':\s*(\[.*?\])/,
        /"caption_tracks":\s*(\[.*?\])/,
        /'captionTracks':\s*(\[.*?\])/,
        /"captionTracks":\s*(\[.*?\])/
      ]

      patterns.each do |pattern|
        matches = body.scan(pattern)

        debug_print "Matches for pattern #{pattern}: #{matches}"

        matches.each do |match|
          # 移除不安全的轉義字符
          clean_json = match[0].gsub(/\\(["\\\/bfnrt])/, '\1')
            .gsub(/\\u([0-9a-fA-F]{4})/) { |m| [m[2..].to_i(16)].pack("U") }

          # 嘗試解析 JSON
          caption_tracks = JSON.parse(clean_json)

          caption_tracks.each do |track|
            # 忽略自動生成的字幕
            # next if track['kind'] == 'asr'
            #
            subtitles << {
              language: track["languageCode"],
              name: begin
                track["name"]["simpleText"]
              rescue
                track["name"]
              end,
              url: track["baseUrl"]
            }
          end

          break unless subtitles.empty?
        rescue JSON::ParserError => e
          debug_print "JSON parsing error: #{e.message}"
        end

        break unless subtitles.empty?
      end

      subtitles
    end

    def extract_subtitles_from_api
      subtitles = []

      api_urls = [
        "https://www.youtube.com/api/timedtext?type=list&v=#{@video_id}",
        "https://video.google.com/timedtext?type=list&v=#{@video_id}"
      ]

      api_urls.each do |api_url|
        uri = URI(api_url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

        response = http.request(request)

        debug_print "API URL response: #{response.code}"

        if response.code == "200"
          # 檢查兩種可能的 XML 格式
          response.body.scan(/<track.*?lang_code="(.*?)".*?name="(.*?)"/).each do |match|
            language, name = match

            subtitles << {
              language: language,
              name: name,
              url: "https://www.youtube.com/api/timedtext?lang=#{language}&v=#{@video_id}"
            }
          end
        end

        break unless subtitles.empty?
      rescue => e
        debug_print "API extraction error: #{e.message}"
      end

      subtitles
    end

    def download_subtitle(subtitle)
      url = URI(subtitle[:url] + "&fmt=srt")

      debug_print "Downloading subtitle from: #{url}"

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(url.path + (url.query ? "?#{url.query}" : ""))
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

      response = http.request(request)

      if response.code != "200"
        puts "Failed to download subtitle: HTTP #{response.code}"
        return
      end

      filename = "subtitles/#{@video_id}_#{subtitle[:language]}.srt"

      File.write(filename, response.body)

      puts "Downloaded subtitle for #{subtitle[:language]} to #{filename}"
    end

    def download_all_subtitles(subtitles)
      subtitles.each do |subtitle|
        download_subtitle(subtitle)
      end
    end

    def download_specific_language(subtitles)
      matching_subtitles = subtitles.select { |s| s[:language] == @options[:language] }

      if matching_subtitles.empty?
        puts "No subtitles found for language: #{@options[:language]}"
        exit 1
      end

      matching_subtitles.each do |subtitle|
        download_subtitle(subtitle)
      end
    end
  end
end
