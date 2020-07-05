# frozen_string_literal: true

class ConvidTweet
    require "net/http"

    def initialize
        require "logger"
        @logger = Logger.new(STDOUT)
    end

    def main_exec(base_day)
        # 設定を読み込む
        one_at_a_time = Mutex.new
        download_path = "downloads/"
        file_name = "settings.yaml"
        yaml = load_settings(file_name)

        accounts = yaml["accounts"]

        threads = []
        accounts.each do |area|
            threads << Thread.new do
                request_and_tweet(area, base_day, one_at_a_time, download_path)
            end
        end

        # 全てのスレッドを待つ
        threads.each(&:join)
    end

    # 設定を読み込む
    def load_settings(file_name)
        begin
            yaml = YAML.load_file(file_name)

            if yaml.class == FalseClass || !yaml.key?("accounts") || yaml["accounts"].nil? || yaml["accounts"].length == 0 then
                @logger.error("accounts is not defined.")
                @logger.error("please confirm file settings.yaml.")
                return nil
            end

            accounts = yaml["accounts"]

            accounts.each do |area|
                if area.nil? || area.first == "" || area.length < 2 then
                    @logger.error("area not defined or not completely defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                area_name = area.first
                area_prop = area[1]
                if area_prop.nil? then
                    @logger.error("area property for #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !area_prop.key?("csv") || area_prop["csv"].nil? || area_prop["csv"] == "" then
                    @logger.error("csv location for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !area_prop.key?("twitter") || area_prop["twitter"].nil? then
                    @logger.error("twitter for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !area_prop.key?("date") || area_prop["date"].nil? then
                    @logger.error("date for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !area_prop.key?("column") || area_prop["column"].nil? then
                    @logger.error("column for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                twitter = area_prop["twitter"]
                if !twitter.key?("consumer_key") || twitter["consumer_key"].nil? then
                    @logger.error("twitter consumer_key for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !twitter.key?("consumer_secret") || twitter["consumer_secret"].nil? then
                    @logger.error("twitter consumer_secret for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !twitter.key?("access_token") || twitter["access_token"].nil? then
                    @logger.error("twitter access_token for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
                if !twitter.key?("access_token_secret") || twitter["access_token_secret"].nil? then
                    @logger.error("twitter access_token_secret for area #{area_name} not defined.")
                    @logger.error("please confirm file settings.yaml.")
                    return nil
                end
            end

            return yaml
        rescue Exception => e
            @logger.error("error happend when reading yaml.error detail is following:")
            @logger.error(e)
            return nil
        end
    end

    # ファイルをダウンロードする
    def download(url, download_path, file_name)
        begin
            download_url = url
            # HTTP定義を行う
            download_uri = uri = URI.parse(download_url)
            http = Net::HTTP.new(download_uri.host, download_uri.port)
            http.use_ssl = true
            req = Net::HTTP::Get.new(download_uri.path)
            
            @logger.info("downloading url : #{download_url}")
            
            # ダウンロードをリクエストする
            response = http.request(req)

            # 保存先パスを定義
            file_path = download_path + file_name
            # ファイルが存在する場合は削除する
            if File.exist?(file_path) then
                File.delete(file_path)
            end
            # ファイルを保存する
            open(file_path, "wb") do |file|
                file.write(response.body)
            end
            
            @logger.info("downloaded url : #{download_url}")

            return file_path
        rescue Exception => e
            @logger.error("error happened when downloading url: #{url}")
            @logger.error("please confirm following excetion message:")
            @logger.error(e)
            return nil
        end
    end

    # CSVファイルを読み込み、基準日と前日の人数を取得する
    def analyze_csv(csv_path, column_index, base_date, date_format)
        begin
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
                if row.length > column_index then
                    row_date = row[actualy_col_index].strip
                    if row_date == base_date_str then
                        # 基準日と同じの場合
                        base_day_count += 1
                    elsif row_date == prev_day_str then
                        # 前日と同じの場合
                        prev_day_count += 1
                    end
                end
            end
            @logger.info("analyze csv file end: #{base_day_count.to_s}, #{prev_day_count.to_s}")
            return [base_day_count, prev_day_count]
        rescue Exception => e
            @logger.error("error happened when analyze csv file: #{csv_path}")
            @logger.error("please confirm following exception message:")
            @logger.error(e)
            return [nil, nil]
        end
    end

    # ツイートする
    def tweet(message, twitter)
        begin
            consumer_key = twitter["consumer_key"]
            consumer_secret = twitter["consumer_secret"]
            access_token = twitter["access_token"]
            access_token_secret = twitter["access_token_secret"]
            client = Twitter::REST::Client.new do |config|
                config.consumer_key = consumer_key
                config.consumer_secret = consumer_secret
                config.access_token = access_token
                config.access_token_secret = access_token_secret
            end
            client.update(message)
            return true
        rescue Exception => e
            @logger.error("error happend when tweet.error detail is following:")
            @logger.error(e)
            return false
        end
    end

    # リクエスト、ツイートする
    def request_and_tweet(area, base_day, lock_obj, download_path)
        # 設定を取得
        name = area.first
        area_prop = area[1]
        url = area_prop["csv"]
        twitter = area_prop["twitter"]
        column_index = area_prop["column"].to_i
        date_format = area_prop["date"]
        # 終日回す
        @logger.info("start thread for area: #{name}")
        while true do
            start_time = Time.now.to_i
            @logger.info("[#{name}] run at time:" + Time.now.to_s)

            # 一時保存用ファイル名設定
            file_name = name + Time.now.strftime("%Y%m%d%H%M%S") + ".csv"
            file_path = ""

            3.times do
                # 3回ダウンロードを試す
                file_path = download(url, download_path, file_name)
                break if !file_path.nil?
            end

            # CSVファイルを分析
            results = analyze_csv(file_path, column_index, base_day, date_format)

            # 基準日データが存在しない場合、1時間以降に起動する
            next_run_wait_seconds = 3600
            
            # 基準日のデータが存在する場合、ツイートする
            if !results.nil? && results.length == 2 && !results[0].nil? && !results[1].nil? && results[0] > 0 && results[1] > 0 then
                @logger.info("[#{name}] end today run at time:" + Time.now.to_s)
                # 次回は翌日の8時から実行する
                next_run_wait_seconds = Date.today.next_day.to_time.to_i + 8 * 3600 - Time.now.to_i
                signal = "+"
                added_count = results[0] - results[1]
                percent = (added_count * 100 / results[1]).to_i.to_s + "%"
                if added_count < 0 then
                    signal = ""
                end
                message = sprintf("「本日の新規陽性者数は%s人です。（前日比 %s%s人,%s%s）」", results[0], signal, added_count, signal, percent)
                @logger.info(message)
                lock_obj.synchronize do
                    tweet(message, twitter)
                    sleep 5
                end
                file_name = name + Time.now.strftime("%Y%m%d") + ".csv"
                # ファイルが存在する場合は名前を変更する
                if File.exist?(file_path) then
                    File.rename(file_path, download_path + file_name)
                end
            else
                # ファイルが存在する場合は削除する
                if File.exist?(file_path) then
                    File.delete(file_path)
                end
            end

            wait_seconds = start_time + next_run_wait_seconds - Time.now.to_i
            @logger.info("[#{name}] wait seconds for next run:" + wait_seconds.to_s)
            sleep(wait_seconds) if wait_seconds > 0
        end
    end
end
