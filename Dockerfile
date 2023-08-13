# Use the latest foundry image
FROM ghcr.io/foundry-rs/foundry

# Copy our source code into the container
WORKDIR /app

RUN apk add --no-cache make git bash jq

COPY . .

# Default port for anvil
EXPOSE 8545