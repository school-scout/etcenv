FROM ruby

ADD . /usr/src/app
WORKDIR /usr/src/app
RUN gem build etcenv.gemspec
RUN gem install --no-document etcenv*.gem

ENTRYPOINT ["etcenv"]
