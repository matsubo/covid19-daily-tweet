# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

require './CovidTweet.rb'
puts CovidTweet.new.main_exec(Date.today)
