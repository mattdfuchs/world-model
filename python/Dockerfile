FROM python:3.11-slim

WORKDIR /app

COPY pyproject.toml /app/pyproject.toml
COPY README.md /app/README.md
COPY src /app/src
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		git \
	&& rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -U pip setuptools wheel
RUN pip install --no-cache-dir -e .

# Install Lean (elan + lake) for LeanInteract usage.
RUN install-lean

ENV PATH="/root/.elan/bin:${PATH}"

EXPOSE 7010

CMD ["uvicorn", "world_model.mcp_server:app", "--host", "0.0.0.0", "--port", "7010"]
