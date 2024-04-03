# frozen_string_literal: true

require_relative '../lib/covid_tweet_process'

RSpec.describe CovidTweetProcess do
  let(:prefecture) { 'ehime' }
  let(:account) { YAML.load_file('settings.yaml')['accounts'][prefecture] }

  describe '#check_andpublish' do
    it 'does not raise error' do
      covid_tweet = described_class.new(prefecture, account)
      expect do
        VCR.use_cassette('no_tweet_csv_download') do
          covid_tweet.check_and_publish
        end
      end.not_to raise_error
    end
  end

  describe '#download' do
    let(:urls) { %w[https://www.pref.ehime.jp/opendata-catalog/dataset/2174/resource/7073/380008_ehime_covid19_patients.csv] }

    it 'does not raise error' do
      covid_tweet = described_class.new(prefecture, account)
      expect do
        VCR.use_cassette('no_tweet_csv_download') do
          covid_tweet.send(:download, urls)
        end
      end.not_to raise_error
    end
  end

  describe '#get_message' do
    describe 'tokyo' do
      let(:prefecture) { '東京都' }

      context '0, 0' do
        let(:base_day_count) { 0 }
        let(:prev_day_count) { 0 }
        let(:output) { '本日の新規陽性者数は0人です。（前日比 ±0人） #covid19 #東京都 #新型コロナウイルス' }

        it 'matches the response' do
          expect(described_class.new(prefecture, account).send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end

      context '20, 30' do
        let(:base_day_count) { 20 }
        let(:prev_day_count) { 30 }
        let(:output) { '本日の新規陽性者数は20人です。（前日比 -10人,-34%） #covid19 #東京都 #新型コロナウイルス' }

        it 'matches the response' do
          expect(described_class.new(prefecture, account).send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end

      context '30, 20' do
        let(:base_day_count) { 30 }
        let(:prev_day_count) { 20 }
        let(:output) { '本日の新規陽性者数は30人です。（前日比 +10人,+50%） #covid19 #東京都 #新型コロナウイルス' }

        it 'matches the response' do
          expect(described_class.new(prefecture, account).send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end

      context '30, 20' do
        let(:base_day_count) { 1 }
        let(:prev_day_count) { 0 }
        let(:output) { '本日の新規陽性者数は1人です。（前日比 +1人） #covid19 #東京都 #新型コロナウイルス' }

        it 'matches the response' do
          expect(described_class.new(prefecture, account).send(:get_message, prefecture, base_day_count, prev_day_count)).to eq output
        end
      end
    end
  end

  describe '#signal' do
    context 'positive' do
      let(:diff) { 30 }

      it 'is positive' do
        expect(described_class.new(prefecture, account).send(:get_signal, diff)).to eq '+'
      end
    end

    context 'zero' do
      let(:diff) { 0 }

      it 'is positive' do
        expect(described_class.new(prefecture, account).send(:get_signal, diff)).to eq '±'
      end
    end

    context 'negative' do
      let(:diff) { -100 }

      it 'is positive' do
        expect(described_class.new(prefecture, account).send(:get_signal, diff)).to eq '-'
      end
    end
  end
end
