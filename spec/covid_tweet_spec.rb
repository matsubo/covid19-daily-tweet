require './covid_tweet.rb'

RSpec.describe CovidTweet do
  describe "#download" do
    let(:url) { 'https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_patients.csv' }
    let(:file_name) { 'test.csv' }
    it "returns 0 for an all gutter game" do
      covid_tweet = CovidTweet.new
      expect { covid_tweet.download(url, file_name) }.not_to raise_error
    end
  end
end
