# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

require_relative '../lib/covid_graph'

RSpec.describe CovidGraph do
  let(:prefecture) { 'tokyo' }
  let(:account) { YAML.load_file('settings.yaml')['accounts'][prefecture] }

  describe '#create' do
    it 'should not raise error' do
      expect { CovidGraph.new(File.open('spec/fixture/tokyo.csv'), account).create }.not_to raise_error
    end
  end
end
