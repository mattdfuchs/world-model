FROM alpine:3.20

ARG NEO4J_MCP_VERSION=v1.3.0
ARG TARGETARCH

RUN apk add --no-cache ca-certificates curl

WORKDIR /app

RUN set -eu; \
  case "${TARGETARCH}" in \
    amd64) asset="neo4j-mcp_Linux_x86_64.tar.gz" ;; \
    arm64) asset="neo4j-mcp_Linux_arm64.tar.gz" ;; \
    *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  curl -fsSL \
    "https://github.com/neo4j/mcp/releases/download/${NEO4J_MCP_VERSION}/${asset}" \
    -o /tmp/neo4j-mcp.tar.gz; \
  version_no_v="${NEO4J_MCP_VERSION#v}"; \
  curl -fsSL \
    "https://github.com/neo4j/mcp/releases/download/${NEO4J_MCP_VERSION}/neo4j-mcp_${version_no_v}_checksums.txt" \
    -o /tmp/neo4j-mcp-checksums.txt; \
  expected_sha="$(grep " ${asset}$" /tmp/neo4j-mcp-checksums.txt | sed -e 's/^sha256://' -e 's/ .*//')"; \
  if [ -z "${expected_sha}" ]; then \
    echo "Checksum not found for ${asset}" >&2; \
    exit 1; \
  fi; \
  actual_sha="$(sha256sum /tmp/neo4j-mcp.tar.gz | awk '{print $1}')"; \
  if [ "${expected_sha}" != "${actual_sha}" ]; then \
    echo "Checksum mismatch for ${asset}" >&2; \
    exit 1; \
  fi; \
  tar -xzf /tmp/neo4j-mcp.tar.gz -C /app; \
  chmod +x /app/neo4j-mcp; \
  rm /tmp/neo4j-mcp.tar.gz /tmp/neo4j-mcp-checksums.txt

EXPOSE 7011

ENTRYPOINT ["/app/neo4j-mcp"]
