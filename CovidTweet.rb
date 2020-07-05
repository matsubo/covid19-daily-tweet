# frozen_string_literal: true

class CovidTweet
  require 'net/http'

  DOWNLOAD_DIR = 'downloads'

  def initialize
    require 'logger'
    @logger = Logger.new(STDOUT)
  end

  def main_exec(base_day)
    # 設定を読み込む
    file_name = 'settings.yaml'
    yaml = load_settings(file_name)

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

  # 設定を読み込む
  def load_settings(file_name)
    yaml = YAML.load_file(file_name)

    raise 'YAML setting is invalid' if !yaml.key?('accounts') || yaml['accounts'].nil? || yaml['accounts'].empty?

    accounts = yaml['accounts']

    accounts.each do |area|
      if area.nil? || area.first == '' || area.length < 2
        @logger.error('area not defined or not completely defined.')
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      area_name = area.first
      area_prop = area[1]
      if area_prop.nil?
        @logger.error("area property for #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !area_prop.key?('csv') || area_prop['csv'].nil? || area_prop['csv'] == ''
        @logger.error("csv location for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !area_prop.key?('twitter') || area_prop['twitter'].nil?
        @logger.error("twitter for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !area_prop.key?('date') || area_prop['date'].nil?
        @logger.error("date for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !area_prop.key?('column') || area_prop['column'].nil?
        @logger.error("column for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      twitter = area_prop['twitter']
      if !twitter.key?('consumer_key') || twitter['consumer_key'].nil?
        @logger.error("twitter consumer_key for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !twitter.key?('consumer_secret') || twitter['consumer_secret'].nil?
        @logger.error("twitter consumer_secret for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      if !twitter.key?('access_token') || twitter['access_token'].nil?
        @logger.error("twitter access_token for area #{area_name} not defined.")
        @logger.error('please confirm file settings.yaml.')
        return nil
      end
      next unless !twitter.key?('access_token_secret') || twitter['access_token_secret'].nil?

      @logger.error("twitter access_token_secret for area #{area_name} not defined.")
      @logger.error('please confirm file settings.yaml.')
      return nil
    end

    yaml
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
    true
  end

  # リクエスト、ツイートする
  def request_and_tweet(area, base_day)
    # 設定を取得
    name = area.first
    area_prop = area[1]
    url = area_prop['csv']
    twitter = area_prop['twitter']
    column_index = area_prop['column'].to_i
    date_format = area_prop['date']

    # 終日回す
    @logger.info("start thread for area: #{name}")
    loop do
      start_time = Time.now.to_i
      @logger.info("[#{name}] run at time:" + Time.now.to_s)

      # 一時保存用ファイル名設定
      file_name = name + Time.now.strftime('%Y%m%d%H%M%S') + '.csv'
      file_path = ''

      Retriable.retriable do
        file_path = download(url, file_name)
      end

      # CSVファイルを分析
      results = analyze_csv(file_path, column_index, base_day, date_format)

      # 基準日データが存在しない場合、1時間以降に起動する
      next_run_wait_seconds = 3600

      # 基準日のデータが存在する場合、ツイートする
      if results[:base_day_count] > 0 && results[:prev_day_count] > 0
        @logger.info("[#{name}] end today run at time:" + Time.now.to_s)
        # 次回は翌日の8時から実行する
        next_run_wait_seconds = Date.today.next_day.to_time.to_i + 8 * 3600 - Time.now.to_i
        signal = '+'
        diff = results[:base_day_count] - results[:prev_day_count]
        percent = (diff * 100 / results[:prev_day_count]).to_i.to_s + '%'
        signal = '' if diff == 0
        message = format('「本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s）」', results[0], signal, diff, signal, percent)
        @logger.info(message)

        tweet(message, twitter)

        file_name = name + Time.now.strftime('%Y%m%d') + '.csv'

        # ファイルが存在する場合は名前を変更する
        File.rename(file_path, File.join(DOWNLOAD_DIR, file_name)) if File.exist?(file_path)
      else
        # ファイルが存在する場合は削除する
        File.delete(file_path) if File.exist?(file_path)
      end

      wait_seconds = start_time + next_run_wait_seconds - Time.now.to_i
      @logger.info("[#{name}] wait seconds for next run:" + wait_seconds.to_s)
      sleep(wait_seconds) if wait_seconds > 0
    end
  end
end
