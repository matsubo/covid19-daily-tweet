# frozen_string_literal: true

require_relative 'covid_tweet_process'

# Make a tweet of today's report.
class CovidTweet
  def main
    # 設定を読み込む
    yaml = YAML.load_file('settings.yaml')

    mutex = Mutex.new
    threads = yaml['accounts'].map do |key, account|
      Thread.new do
        CovidTweetProcess.new(key, account, nil, mutex).daemon
      end
    end

    # 全てのスレッドを待つ
    threads.each(&:join)
  end
end
