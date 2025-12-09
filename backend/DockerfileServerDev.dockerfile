# Version 3 with UV
FROM ghcr.io/astral-sh/uv:0.9 AS uv

FROM mcr.microsoft.com/devcontainers/python:3.13-bullseye

# Update packages and Install cron
# RUN apt-get install -y cron

# COPY ./scripts/crontab /etc/cron.d/my-crontab
# COPY ./scripts/clear_old_files.sh /app/clear_old_files.sh

# RUN chmod +x /app/clear_old_files.sh && chmod 0644 /etc/cron.d/my-crontab && crontab /etc/cron.d/my-crontab

ENV PYTHONUNBUFFERED=1

# Create a virtual environment with uv inside the container
RUN --mount=from=uv,source=/uv,target=./uv \
    ./uv venv /opt/venv

# We need to set this environment variable so that uv knows where
# the virtual environment is to install packages
ENV VIRTUAL_ENV=/opt/venv

# Make sure that the virtual environment is in the PATH so
# we can use the binaries of packages that we install such as pip
# without needing to activate the virtual environment explicitly
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace

# Copy the requirements file into the container
COPY requirements.txt .

# Install runtime system libraries required by pango/cairo (weasyprint, cairosvg, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    fonts-dejavu-core \
  && rm -rf /var/lib/apt/lists/*

# Install the packages with uv using --mount=type=cache to cache the downloaded packages
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=from=uv,source=/uv,target=./uv \
    ./uv pip install  -r requirements.txt

# install chrome (for selenium)
# RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg   
# RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
# RUN apt update && apt install -y google-chrome-stable

CMD ["python","-m","debugpy","--listen","0.0.0.0:5678","-m","uvicorn","app.main:app","--host","0.0.0.0","--port","8000","--reload","--workers","4"]