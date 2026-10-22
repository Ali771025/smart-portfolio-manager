FROM python:3.11-slim

WORKDIR /app

# Switch Debian mirror (Runflare)
RUN echo "deb http://mirror-linux.runflare.com/debian trixie main" > /etc/apt/sources.list && \
    echo "deb http://mirror-linux.runflare.com/debian-security trixie-security main" >> /etc/apt/sources.list

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies

COPY requirements.txt .
RUN pip install --no-cache-dir -i https://mirror-pypi.runflare.com/simple \
    --trusted-host mirror-pypi.runflare.com \
    -r requirements.txt

# Copy app
COPY . .

CMD alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000
