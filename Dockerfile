# Use official Bun image
FROM oven/bun:latest

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json bun.lockb ./
RUN bun install

# Copy application source code
COPY . .

# Build the production bundle (bakes VITE_* from .env into dist/)
RUN bun run build

# Expose port

EXPOSE 3030

# Start command
CMD ["bun", "run", "preview", "--port", "3030"]
