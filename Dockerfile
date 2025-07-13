# Slim Dockerfile for Claude token refresh
FROM node:22-alpine

# Install only essential packages
RUN apk add --no-cache \
    bash \
    jq \
    coreutils \
    curl

# Create claude user
RUN adduser -D -s /bin/bash claude

# Create necessary directories with proper permissions
RUN mkdir -p /logs /output /creds && \
    chown -R claude:claude /logs /output /creds

USER claude
WORKDIR /home/claude

# Copy refresh script
COPY --chown=claude:claude docker-refresh-claude.sh /usr/local/bin/

# Set up directories
RUN mkdir -p /home/claude/.claude

# Make script executable
USER root
RUN chmod +x /usr/local/bin/docker-refresh-claude.sh
USER claude

ENTRYPOINT ["/usr/local/bin/docker-refresh-claude.sh"]