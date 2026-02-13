FROM n8nio/n8n:2.2.6

USER root

# Patch 1: strip $schema from zodToJsonSchema output
RUN find /usr/local/lib/node_modules/n8n -name "zodToJsonSchema.js" \
      -path "*/@langchain/core/*" -exec \
    sed -i 's|combined\.\$schema = |void |g' {} \;

USER node
