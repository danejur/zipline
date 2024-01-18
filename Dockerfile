# Use the Prisma binaries image as the first stage
FROM ghcr.io/diced/prisma-binaries:5.1.x as prisma

# Use Alpine Linux as the second stage
FROM node:18-alpine3.16 as base

# Set the working directory
WORKDIR /zipline

# Copy the necessary files from the project
COPY prisma ./prisma

COPY .yarn ./.yarn
COPY package*.json ./
COPY yarn*.lock ./
COPY .yarnrc.yml ./

# Copy the prisma binaries from prisma stage
COPY --from=prisma /prisma-engines /prisma-engines
ENV PRISMA_QUERY_ENGINE_BINARY=/prisma-engines/query-engine \
  PRISMA_SCHEMA_ENGINE_BINARY=/prisma-engines/schema-engine \
  PRISMA_CLI_QUERY_ENGINE_TYPE=binary \
  PRISMA_CLIENT_ENGINE_TYPE=binary \
  ZIPLINE_DOCKER_BUILD=true \
  NEXT_TELEMETRY_DISABLED=1

# Install the dependencies
RUN yarn install --immutable

FROM base as builder

COPY src ./src
COPY next.config.js ./next.config.js
COPY tsup.config.ts ./tsup.config.ts
COPY tsconfig.json ./tsconfig.json
COPY mimes.json ./mimes.json
COPY public ./public

# Run the build
RUN yarn build

# Use Alpine Linux as the final image
FROM base

# Install the necessary packages
RUN apk add --no-cache perl procps tini

COPY --from=prisma /prisma-engines /prisma-engines
ENV PRISMA_QUERY_ENGINE_BINARY=/prisma-engines/query-engine \
  PRISMA_SCHEMA_ENGINE_BINARY=/prisma-engines/schema-engine \
  PRISMA_CLI_QUERY_ENGINE_TYPE=binary \
  PRISMA_CLIENT_ENGINE_TYPE=binary \
  ZIPLINE_DOCKER_BUILD=true \
  NEXT_TELEMETRY_DISABLED=1


# Copy only the necessary files from the previous stage
COPY --from=builder /zipline/dist ./dist
COPY --from=builder /zipline/.next ./.next

COPY --from=builder /zipline/mimes.json ./mimes.json
COPY --from=builder /zipline/next.config.js ./next.config.js
COPY --from=builder /zipline/public ./public

# Copy Startup Script
COPY docker-entrypoint.sh /zipline

# Make Startup Script Executable
RUN chmod a+x /zipline/docker-entrypoint.sh && rm -rf /zipline/src

# Clean up
RUN rm -rf /tmp/* /root/* 
RUN yarn cache clean --all

# Set the entrypoint to the startup script
ENTRYPOINT ["tini", "--", "/zipline/docker-entrypoint.sh"]