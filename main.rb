# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

require './ConvidTweet.rb'
puts ConvidTweet.new.main_exec(Date.today)
