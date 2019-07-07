FROM ruby:2.4-alpine
MAINTAINER tyage <namatyage@gmail.com>

ARG SRCDIR="/usr/local/slack-patron"

RUN set -x && \
	apk upgrade --update && \
	apk add --update \
		git \
		build-base \
		openssl \
		nodejs \
		nodejs-npm && \
	echo 'gem: --no-document' >> /etc/gemrc
WORKDIR ${SRCDIR}
COPY . ${SRCDIR}/

RUN     bundle install && \
	./viewer/setup.sh

CMD bundle exec rackup viewer/config.ru -o 0.0.0.0 -p 9292

EXPOSE 9292
