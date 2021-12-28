# frozen_string_literal: true

require_relative 'covid_graph'
require_relative 'wordpress'

# Make a tweet of today's report.
# ```
# require 'bundler/setup'
# Bundler.require
#
# require 'yaml'
# prefecture = 'tokyo'
# account = YAML.load_file('settings.yaml')['accounts'][prefecture]
# CovidTweetProcess.new(prefecture, account).check_and_publish
#
# ````
class CovidTweetProcess
  require 'net/http'
  require 'active_support/all'
  require 'tempfile'
  require 'logger'

  # Data snapshot preserve directory
  DOWNLOAD_DIR = 'downloads'

  # Time of the day to start crawling
  HOURS_TO_START = 14

  def initialize(prefecture, account, base_date = nil, mutex = Mutex.new, force: false)
    @prefecture = prefecture
    @account = account
    @logger = Logger.new(($stdout unless ENV['TEST']))
    @specified_base_date = base_date
    @mutex = mutex
    @force = force
  end

  def base_date
    @specified_base_date || Time.now
  end

  # 常駐
  def daemon
    loop do
      if File.exist?(archive_file)
        log('Sleeping until tomorrow evening.')
        sleep((1.day.since.midnight + HOURS_TO_START.hour).to_i - base_date.to_i)
      end

      if Time.now.hour < HOURS_TO_START
        log('Sleeping until today evening.')

        sleep((0.day.since.midnight + HOURS_TO_START.hour).to_i - base_date.to_i)
      end

      begin
        result = check_and_publish
      rescue StandardError => e
        log(e, level: :error)
      end

      unless result
        log('sleeping 10 min')
        sleep(10.minutes.to_i)
      end
    end
  end

  #
  # @return bool true if tweeted, false for nothing
  #
  def check_and_publish
    if !@force && File.exist?(archive_file)
      log('Finishing process due to the file exists.')
      return
    end

    tempfile = nil

    Retriable.retriable do
      tempfile = download(@account['csv'])
    end

    # Check the today's data is updated
    begin
      results = analyze_csv(tempfile)
    rescue CSV::MalformedCSVError => e
      log(e, level: :warn)
      return false
    end

    return false unless results[:base_day_count].positive?

    log(results)

    # Tweet if today's data is updated.
    message = get_message(@account['prefecture_ja'], results[:base_day_count], results[:prev_day_count])

    log(message)

    file = nil
    @mutex.synchronize do
      file = CovidGraph.new(tempfile, @account, base_date).create
    end

    begin
      log('posting to wordpress...')
      response_hash = Wordpress.new(@prefecture, base_date).post(message, file)
    rescue StandardError => e
      log(e, level: :error)
    end

    begin
      log('tweeting...')
      message = message + ' ' + response_hash['link']
      twitter.update(message)
    rescue StandardError => e
      log(e, level: :error)
    end

    FileUtils.chmod('a+r', tempfile)
    FileUtils.mv(tempfile, archive_file)

    true
  end

  private

  #
  # Download and return saved File object
  #
  # @return File
  #
  def download(url)
    log("downloading file: #{url}")

    tempfile = Tempfile.create

    require 'open-uri'
    File.write tempfile, Faraday.get(url).body

    tempfile
  end

  # CSVファイルを読み込み、基準日と前日の人数を取得する
  def analyze_csv(csv_path)
    # get date formatted
    base_date_str = base_date.strftime(@account['date'])
    # get previous date
    prev_day = base_date.prev_day
    prev_day_str = prev_day.strftime(@account['date'])

    prev_day_count = 0
    base_day_count = 0

    actualy_col_index = @account['column'].to_i - 1

    CSV.foreach(csv_path, headers: true, encoding: @account['encoding']) do |row|
      next if row.length < 0
      next if row[actualy_col_index].nil? # next if empty column

      row_date = row[actualy_col_index]&.strip rescue ''
      if row_date == base_date_str
        # 基準日と同じの場合
        base_day_count += 1
      elsif row_date == prev_day_str
        # 前日と同じの場合
        prev_day_count += 1
      end
    end

    {
      base_day_count:,
      prev_day_count:
    }
  end

  def twitter
    twitter_yaml = YAML.load_file('twitter.yaml')
    raise 'twitter setting is empty' unless twitter_yaml

    twitter_config = twitter_yaml[@prefecture]

    raise 'twitter setting is not found' unless twitter_config

    Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_config['consumer_key']
      config.consumer_secret = twitter_config['consumer_secret']
      config.access_token = twitter_config['access_token']
      config.access_token_secret = twitter_config['access_token_secret']
    end
  end

  def archive_file
    File.join(DOWNLOAD_DIR, format('%s%s.csv', @prefecture, base_date.strftime('%Y%m%d')))
  end

  def get_message(prefecture, base_day_count, prev_day_count)
    diff = base_day_count - prev_day_count

    if base_day_count == 0 || prev_day_count == 0
      signal = get_signal(diff)
      format('本日の新規陽性者数は%d人です。（前日比 %s%s人） #covid19 #%s #新型コロナウイルス', base_day_count, signal, diff.abs, prefecture)
    else
      percent = format('%s%%', (diff * 100 / prev_day_count).abs.to_i.to_s)
      signal = get_signal(diff)
      format('本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s） #covid19 #%s #新型コロナウイルス', base_day_count, signal, diff.abs, signal, percent, prefecture)
    end
  end

  def log(message, level: :info)
    @logger.send(level, "[#{@prefecture}]: #{message}")
  end

  def get_signal(diff)
    if diff > 0
      '+'
    elsif diff < 0
      '-'
    elsif diff == 0
      '±'
    end
  end
end
