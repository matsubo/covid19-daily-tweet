# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

require_relative 'lib/covid_tweet'
puts CovidTweet.new.main
