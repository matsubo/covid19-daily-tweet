# frozen_string_literal: true

# Make a tweet of today's report.
class CovidTweet
  require 'net/http'
  require 'active_support/all'
  require 'tempfile'

  DOWNLOAD_DIR = 'downloads'

  def initialize
    require 'logger'
    @logger = Logger.new((STDOUT unless ENV['TEST']))
  end

  def main_exec(base_day)
    # 設定を読み込む
    yaml = YAML.load_file('settings.yaml')

    threads = []
    yaml['accounts'].each do |account|
      threads << Thread.new do
        request_and_tweet(account, base_day)
      end
    end

    # 全てのスレッドを待つ
    threads.each(&:join)
  end

  # リクエスト、ツイートする
  def request_and_tweet(account, base_day)
    # 設定を取得
    prefecture = account['prefecture']
    prefecture_ja = account['prefecture_ja']
    url = account['csv']
    twitter = account['twitter']
    column_index = account['column'].to_i
    date_format = account['date']
    encoding = account['encoding']

    # 終日回す
    @logger.info("[#{prefecture}] started.")
    loop do
      if File.exist?(archive_file(prefecture, base_day))
        @logger.info("[#{prefecture}] Waiting until tomorrow morning.")
        sleep((1.day.since.midnight + 8.hour).to_i - Time.now.to_i)
      end

      tempfile = nil
      Retriable.retriable do
        tempfile = download(url)
      end

      # Check the today's data is updated
      results = analyze_csv(tempfile, column_index, base_day, date_format, encoding)

      @logger.info("[#{prefecture}] Parse result: #{results}")

      # Tweet if today's data is updated.
      if results[:base_day_count].positive? && results[:prev_day_count].positive?
        tweet(twitter, get_message(prefecture_ja, results[:base_day_count], results[:prev_day_count]))
        File.rename(tempfile, archive_file(prefecture, base_day))
      end

      @logger.info("[#{prefecture}] Sleeping 30 min")
      sleep(30.minutes.to_i)
    end
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

    @logger.info("downloading file: #{url}")

    response = http.request(req)

    tempfile = Tempfile.create

    File.write(tempfile, response.body)

    tempfile
  end

  # CSVファイルを読み込み、基準日と前日の人数を取得する
  def analyze_csv(csv_path, column_index, base_date, date_format, encoding)
    # get date formatted
    base_date_str = base_date.strftime(date_format)
    # get previous date
    prev_day = base_date.prev_day
    prev_day_str = prev_day.strftime(date_format)

    prev_day_count = 0
    base_day_count = 0

    actualy_col_index = column_index - 1
    CSV.foreach(csv_path, encoding: encoding) do |row|
      # 1行ずつ取得する
      if row.length > column_index
        row_date = row[actualy_col_index].strip
        if row_date == base_date_str
          # 基準日と同じの場合
          base_day_count += 1
        elsif row_date == prev_day_str
          # 前日と同じの場合
          prev_day_count += 1
        end
      end
    end

    {
      base_day_count: base_day_count,
      prev_day_count: prev_day_count
    }
  end

  # ツイートする
  def tweet(twitter, message)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = twitter['consumer_key']
      config.consumer_secret = twitter['consumer_secret']
      config.access_token = twitter['access_token']
      config.access_token_secret = twitter['access_token_secret']
    end

    @logger.info(message)
    client.update(message)
  end

  def archive_file(prefecture, _base_day)
    File.join(DOWNLOAD_DIR, prefecture + Time.now.strftime('%Y%m%d') + '.csv')
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
end
