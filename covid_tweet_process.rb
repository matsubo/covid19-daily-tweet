# frozen_string_literal: true

# Make a tweet of today's report.
class CovidTweetProcess
  require 'net/http'
  require 'active_support/all'
  require 'tempfile'
  require 'logger'

  DOWNLOAD_DIR = 'downloads'

  def initialize(account)
    @account = account
    @twitter = twitter
    @logger = Logger.new((STDOUT unless ENV['TEST']))
  end

  # 常駐
  def daemon
    loop do
      if File.exist?(archive_file)
        log('Sleeping until tomorrow morning.')
        sleep((1.day.since.midnight + 8.hour).to_i - Time.now.to_i)
      end

      unless check_and_tweet
        log('sleeping 30 min')
        sleep(30.minutes.to_i)
      end
    end
  end

  #
  # @return bool true if tweeted, false for nothing
  #
  def check_and_tweet
    tempfile = nil

    Retriable.retriable do
      tempfile = download(@account['csv'])
    end

    # Check the today's data is updated
    begin
      results = analyze_csv(tempfile)

      log(results)

      return false unless results[:base_day_count].positive? && results[:prev_day_count].positive?

      # Tweet if today's data is updated.
      tweet(get_message(@account['prefecture_ja'], results[:base_day_count], results[:prev_day_count]))
      FileUtils.mv(tempfile, archive_file)
    rescue CSV::MalformedCSVError => e
      log(e, :warn)
      return false
    end

    true
  end

  private

  #
  # Download and return saved File object
  #
  # @return File
  #
  def download(url)
    download_uri = URI.parse(url)
    http = Net::HTTP.new(download_uri.host, download_uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(download_uri.path)

    log("downloading file: #{url}")

    response = http.request(req)

    tempfile = Tempfile.create

    File.write(tempfile, response.body)

    tempfile
  end

  # CSVファイルを読み込み、基準日と前日の人数を取得する
  def analyze_csv(csv_path)
    base_date = Time.now

    # get date formatted
    base_date_str = base_date.strftime(@account['date'])
    # get previous date
    prev_day = base_date.prev_day
    prev_day_str = prev_day.strftime(@account['date'])

    prev_day_count = 0
    base_day_count = 0

    actualy_col_index = @account['column'].to_i - 1

    CSV.foreach(csv_path, encoding: @account['encoding']) do |row|
      next if row.length < 0

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
      base_day_count: base_day_count,
      prev_day_count: prev_day_count
    }
  end

  # ツイートする
  def tweet(message)
    log(message)
    @twitter.update(message)
  end

  def twitter
    twitter_yaml = YAML.load_file('twitter.yaml')
    twitter_config = twitter_yaml[@account['prefecture']]
    twitter = Twitter::REST::Client.new do |config|
      config.consumer_key = twitter_config['consumer_key']
      config.consumer_secret = twitter_config['consumer_secret']
      config.access_token = twitter_config['access_token']
      config.access_token_secret = twitter_config['access_token_secret']
    end

    twitter
  end

  def archive_file
    File.join(DOWNLOAD_DIR, @account['prefecture'] + Time.now.strftime('%Y%m%d') + '.csv')
  end

  def get_message(prefecture, base_day_count, prev_day_count)
    diff = base_day_count - prev_day_count

    if base_day_count == 0
      signal = get_signal(diff)
      format('本日の新規陽性者数は0人です。（前日比 %s%s人） #covid19 #%s', signal, diff.abs, prefecture)
    else
      percent = (diff * 100 / prev_day_count).abs.to_i.to_s + '%'
      signal = get_signal(diff)
      format('本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s） #covid19 #%s', base_day_count, signal, diff.abs, signal, percent, prefecture)
    end
  end

  def log(message, level: :info)
    @logger.send(level, "[#{@account['prefecture']}]: #{message}")
  end

  def get_signal(diff)
    if diff > 0
      '+'
    elsif diff < 0
      '-'
    elsif diff == 0
      '+-'
    end
  end
end
