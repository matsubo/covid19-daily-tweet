# frozen_string_literal: true

# Make a tweet of today's report.
class CovidTweet
  def main
    # 設定を読み込む
    yaml = YAML.load_file('settings.yaml')

    threads = []
    yaml['accounts'].each do |account|
      threads << Thread.new do
        CovidTweetProcess.new(account).daemon
      end
    end

    # 全てのスレッドを待つ
    threads.each(&:join)
  end
end
