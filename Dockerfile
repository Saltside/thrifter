FROM ruby:3.4.3-bullseye

RUN apt-get update && apt-get install -y build-essential

RUN mkdir -p /app/lib/thrifter

WORKDIR /app

# Add only the files that are required to run bundle installer.
# Remaining library code will be provided via a volume
ADD Gemfile /app/
ADD thrifter.gemspec /app/
ADD lib/thrifter/version.rb /app/lib/thrifter/

RUN bundle install -j $(nproc)

CMD [ "bundle", "console" ]
