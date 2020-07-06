# frozen_string_literal: true

require './covid_tweet.rb'

RSpec.describe CovidTweet do
  describe '#download' do
    let(:url) { 'https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_patients.csv' }
    it 'should not raise error'  do
      covid_tweet = CovidTweet.new
      expect { covid_tweet.send(:download, url) }.not_to raise_error
    end
  end
  describe '#get_message' do
    describe 'tokyo' do
      let(:prefecture) { '東京都' }
      context '0, 0' do
        let(:base_day_count) { 0 }
        let(:prev_day_count) { 0 }
        let(:output) { '本日の新規陽性者数は0人です。（前日比 +-0人） #covid19 #東京都' }

        it 'should match the response' do
          expect(CovidTweet.new.send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end
      context '20, 30' do
        let(:base_day_count) { 20 }
        let(:prev_day_count) { 30 }
        let(:output) { '本日の新規陽性者数は20人です。（前日比 -10人,-34%） #covid19 #東京都' }

        it 'should match the response' do
          expect(CovidTweet.new.send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end
      context '30, 20' do
        let(:base_day_count) { 30 }
        let(:prev_day_count) { 20 }
        let(:output) { '本日の新規陽性者数は30人です。（前日比 +10人,+50%） #covid19 #東京都' }

        it 'should match the response' do
          expect(CovidTweet.new.send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end
    end
  end
end
