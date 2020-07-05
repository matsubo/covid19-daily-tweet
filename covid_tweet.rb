# frozen_string_literal: true

# Make a tweet of today's report.
class CovidTweet
  require 'net/http'
  require 'active_support/all'

  DOWNLOAD_DIR = 'downloads'

  def initialize
    require 'logger'
    @logger = Logger.new((STDOUT unless ENV['TEST']))
  end

  def main_exec(base_day)
    # 設定を読み込む
    yaml = YAML.load_file('settings.yaml')

    accounts = yaml['accounts']

    threads = []
    accounts.each do |area|
      threads << Thread.new do
        request_and_tweet(area, base_day)
      end
    end

    # 全てのスレッドを待つ
    threads.each(&:join)
  end

  # ファイルをダウンロードする
  def download(url, file_name)
    download_url = url
    # HTTP定義を行う
    download_uri = URI.parse(download_url)
    http = Net::HTTP.new(download_uri.host, download_uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(download_uri.path)

    @logger.info("downloading url : #{download_url}")

    # ダウンロードをリクエストする
    response = http.request(req)

    # 保存先パスを定義
    file_path = File.join(DOWNLOAD_DIR, file_name)

    # ファイルが存在する場合は削除する
    File.delete(file_path) if File.exist?(file_path)

    # ファイルを保存する
    File.write(file_path, response.body)

    @logger.info("downloaded url : #{download_url}")

    file_path
  end

  # CSVファイルを読み込み、基準日と前日の人数を取得する
  def analyze_csv(csv_path, column_index, base_date, date_format)
    # get date formatted
    base_date_str = base_date.strftime(date_format)
    # get previous date
    prev_day = base_date.prev_day
    prev_day_str = prev_day.strftime(date_format)

    @logger.info("analyze csv file with date: #{base_date_str} and #{prev_day_str}")

    prev_day_count = 0
    base_day_count = 0

    actualy_col_index = column_index - 1
    CSV.foreach(csv_path) do |row|
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
    @logger.info("analyze csv file end: #{base_day_count}, #{prev_day_count}")
    {
      base_day_count: base_day_count,
      prev_day_count: prev_day_count
    }
  end

  # ツイートする
  def tweet(message, twitter)
    consumer_key = twitter['consumer_key']
    consumer_secret = twitter['consumer_secret']
    access_token = twitter['access_token']
    access_token_secret = twitter['access_token_secret']
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = consumer_key
      config.consumer_secret = consumer_secret
      config.access_token = access_token
      config.access_token_secret = access_token_secret
    end
    client.update(message)
  end

  # リクエスト、ツイートする
  def request_and_tweet(area, base_day)
    # 設定を取得
    prefecture = area.first
    area_prop = area[1]
    url = area_prop['csv']
    twitter = area_prop['twitter']
    column_index = area_prop['column'].to_i
    date_format = area_prop['date']

    # 終日回す
    @logger.info("start thread for area: #{prefecture}")
    loop do
      @logger.info("[#{prefecture}] run at time:" + Time.now.to_s)

      # 一時保存用ファイル名設定
      file_name = prefecture + Time.now.strftime('%Y%m%d%H%M%S') + '.csv'
      file_path = ''

      Retriable.retriable do
        file_path = download(url, file_name)
      end

      # Check the today's data is updated
      results = analyze_csv(file_path, column_index, base_day, date_format)

      # Wait for a while until next check
      next_run_wait_seconds = 30.minutes.to_i

      # Tweet if today's data is updated.
      if results[:base_day_count].positive? && results[:prev_day_count].positive?
        @logger.info("[#{prefecture}] end today run at time:" + Time.now.to_s)

        # 次回は翌日の8時から実行する
        next_run_wait_seconds = 1.day.since.midnight + 8.hour - Time.now.to_i
        signal = '+'
        diff = results[:base_day_count] - results[:prev_day_count]
        percent = (diff * 100 / results[:prev_day_count]).abs.to_i.to_s + '%'
        signal = '-' if diff < 0
        message = format('「本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s）」', results[:base_day_count], signal, diff, signal, percent)
        @logger.info(message)

        tweet(message, twitter)

        file_name = prefecture + Time.now.strftime('%Y%m%d') + '.csv'

        # ファイルが存在する場合は名前を変更する
        File.rename(file_path, File.join(DOWNLOAD_DIR, file_name)) if File.exist?(file_path)
      else
        # ファイルが存在する場合は削除する
        File.delete(file_path) if File.exist?(file_path)
      end

      @logger.info("[#{prefecture}] wait seconds for next run:" + next_run_wait_seconds.to_s)
      sleep(next_run_wait_seconds)
    end
  end
end
