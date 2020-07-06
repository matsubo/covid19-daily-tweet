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
    accounts.each do |account|
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
    url = account['csv']
    twitter = account['twitter']
    column_index = account['column'].to_i
    date_format = account['date']
    encoding = account['encoding']

    puts prefecture
    puts account

    # 終日回す
    @logger.info("start thread for area: #{prefecture}")
    loop do
      @logger.info("[#{prefecture}] run at time:" + Time.now.to_s)

      # 一時保存用ファイル名設定
      file_path = ''

      Retriable.retriable do
        file_path = download(url, get_todays_filename(prefecture))
      end

      # Check the today's data is updated
      results = analyze_csv(file_path, column_index, base_day, date_format, encoding)

      # Wait for a while until next check
      next_run_wait_seconds = 30.minutes.to_i

      # Tweet if today's data is updated.
      if results[:base_day_count].positive? && results[:prev_day_count].positive?
        @logger.info("[#{prefecture}] end today run at time:" + Time.now.to_s)

        # 次回は翌日の8時から実行する
        next_run_wait_seconds = (1.day.since.midnight + 8.hour).to_i - Time.now.to_i
        diff = results[:base_day_count] - results[:prev_day_count]
        percent = (diff * 100 / results[:prev_day_count]).abs.to_i.to_s + '%'

        signal = get_signal(diff)

        message = format('本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s） #covid19 #%s', results[:base_day_count], signal, diff.abs, signal, percent, prefecture)

        @logger.info(message)

        tweet(message, twitter)

        # ファイルが存在する場合は名前を変更する
        File.rename(file_path, File.join(DOWNLOAD_DIR, get_todays_filename(prefecture))) if File.exist?(file_path)
      else
        # ファイルが存在する場合は削除する
        File.delete(file_path) if File.exist?(file_path)
      end

      @logger.info("[#{prefecture}] wait seconds for next run:" + next_run_wait_seconds.to_s)
      sleep(next_run_wait_seconds)
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
  def analyze_csv(csv_path, column_index, base_date, date_format, encoding)
    # get date formatted
    base_date_str = base_date.strftime(date_format)
    # get previous date
    prev_day = base_date.prev_day
    prev_day_str = prev_day.strftime(date_format)

    @logger.info("analyze csv file with date: #{base_date_str} and #{prev_day_str}")

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
    @logger.info("analyze csv file end: #{base_day_count}, #{prev_day_count}")
    {
      base_day_count: base_day_count,
      prev_day_count: prev_day_count
    }
  end

  # ツイートする
  def tweet(message, twitter)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = twitter['consumer_key']
      config.consumer_secret = twitter['consumer_secret']
      config.access_token = twitter['access_token']
      config.access_token_secret = twitter['access_token_secret']
    end
    client.update(message)
  end


  def get_todays_filename(prefecture)
    prefecture + Time.now.strftime('%Y%m%d') + '.csv'
  end
end
