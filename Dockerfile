ARG RUBY_VERSION=4.0.5
FROM ruby:$RUBY_VERSION-alpine AS base

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Both database libraries: DATABASE_URL picks the adapter at boot, so neither can
# be dropped as bloat.
RUN apk add --no-cache sqlite-libs libpq tzdata

FROM base AS build

RUN apk add --no-cache build-base git pkgconf sqlite-dev postgresql-dev yaml-dev

COPY Gemfile Gemfile.lock ./

# Gems ship their own tests, docs and C sources, and none of that survives into a
# running container usefully.
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/cache "${BUNDLE_PATH}"/ruby/*/cache && \
    ruby -e "puts Dir['${BUNDLE_PATH}/gems/*/{test,tests,spec,examples,sample,doc,docs}'] + \
                  Dir['${BUNDLE_PATH}/gems/*/ext/**/*.{c,h,o,S}']" | xargs rm -rf && \
    bundle exec bootsnap precompile --gemfile

COPY . .
RUN bundle exec bootsnap precompile app/ lib/

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN addgroup -g 1000 -S rails && \
    adduser -u 1000 -G rails -S -h /home/rails rails && \
    mkdir -p storage tmp && \
    chown -R rails:rails db storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
