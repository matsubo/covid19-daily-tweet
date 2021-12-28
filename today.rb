# usage
#   30,59 9-14 * * * cd /path/to/covid19-daily-tweet && docker-compose run app bundle exec ruby today.rb > /tmp/covid19.log
require 'bundler/setup'
Bundler.require

require '/app/lib/covid_tweet_process'
require 'active_support/all'

# 設定を読み込む
yaml = YAML.load_file('settings.yaml')

logger = Logger.new(($stdout unless ENV['TEST']))

yaml['accounts'].each do |key, account|
  CovidTweetProcess.new(key, account, 0.day.ago).check_and_publish rescue nil
rescue StandardError => e
  logger.error(key)
  logger.error(e)
end
