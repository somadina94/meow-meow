# Debian (glibc), not Alpine: bun install fails extracting sharp's musl tarball on Alpine.
FROM oven/bun:1-debian

WORKDIR /app

COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile || bun install

COPY . .

# VITE_* from .env are baked in at build time
RUN bun run build

EXPOSE 3030

CMD ["bun", "run", "preview", "--port", "3030"]
