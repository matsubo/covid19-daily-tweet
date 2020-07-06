# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

require './covid_tweet.rb'
puts CovidTweet.new.main
