FROM ruby:3.3

RUN apt-get update && apt-get install -y libjemalloc-dev libjemalloc2 && apt-get clean \
       && rm -rf /var/lib/apt/lists/*

