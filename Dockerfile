FROM python:3.6
MAINTAINER jeremy.harris@zenosmosis.com
LABEL description "A Dockerized web parser, which serves a RESTful API with JSON for output."

ENV HTTP_API_PORT=8080
ENV IS_PRODUCTION=1

# Fix for google-chrome-unstable
# See https://crbug.com/795759
# (note: libgconf-2-4 may not need to be installed)

# Install latest chrome dev package and fonts to support major charsets (Chinese, Japanese, Arabic, Hebrew, Thai and a few others)
# Note: this installs the necessary libs to make the bundled version of Chromium that Puppeteer installs, work.
# apt-get update && apt-get install -y wget --no-install-recommends \
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y gcc python-dev nodejs yarn git libgconf-2-4 google-chrome-unstable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst ttf-freefont \
      --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && pip install lxml

# It's a good idea to use dumb-init to help prevent zombie chrome processes
ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64 /usr/local/bin/dumb-init
RUN chmod +x /usr/local/bin/dumb-init

ENV NODE_PATH="/usr/local/share/.config/yarn/global/node_modules:${NODE_PATH}"

RUN yarn global add \
    puppeteer@1.4.0 \
    apidoc \
    pm2 \
    typedoc \
    webpack \
    webpack-cli \
    && yarn cache clean

# Add user & set directory permissions
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser \
    && mkdir -p /app \
    && chown -R pptruser:pptruser /app \
    && chmod g+s /app \
    && chown -R pptruser:pptruser /home/pptruser \
    && mkdir -p /usr/local/share/.config/yarn/global/node_modules \
    && chown -R pptruser:pptruser /usr/local/share/.config/yarn/global/node_modules \
    && chmod g+s /usr/local/share/.config/yarn/global/node_modules

# Enable linking to global Puppeteer
RUN cd /usr/local/share/.config/yarn/global/node_modules/puppeteer \
    && yarn link

WORKDIR /app

COPY . /app

# Install local Node.js modules, etc.
RUN bash -C ./finalize.sh

# Run everything after as non-privileged user
USER pptruser

# Test as the non-privleged user
# Note: The usage of --forceExit here is to keep the testing engine from preventing the rest of the build if it doesn't exit cleanly (yet has no errors)
RUN yarn test --forceExit

EXPOSE 8080

# @see # @see https://github.com/Yelp/dumb-init
ENTRYPOINT ["dumb-init", "--"]

CMD ["./pm2.start.sh", "--no-daemon"]
