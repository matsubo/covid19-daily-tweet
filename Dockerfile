FROM ruby:3.1

RUN apt-get update && apt-get install -y libjemalloc-dev libjemalloc2 && apt-get clean \
       && rm -rf /var/lib/apt/lists/*
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

