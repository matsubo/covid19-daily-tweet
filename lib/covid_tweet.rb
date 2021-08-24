# frozen_string_literal: true

require_relative 'covid_tweet_process'

# Make a tweet of today's report.
class CovidTweet
  def main
    # 設定を読み込む
    yaml = YAML.load_file('settings.yaml')

    threads = []
    yaml['accounts'].each do |key, account|
      threads << Thread.new do
        CovidTweetProcess.new(key, account).daemon
        sleep 0.5 # to avoid graph lib is not thread safe.
      end
    end

    # 全てのスレッドを待つ
    threads.each(&:join)
  end
end
