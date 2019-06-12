FROM ruby:2.6-alpine
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN apk --update add build-base openssl openssl-dev && bundle install
COPY . /app/
