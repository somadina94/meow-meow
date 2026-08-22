# Debian (glibc), not Alpine: bun install fails extracting sharp's musl tarball on Alpine.
FROM oven/bun:1-debian

WORKDIR /app

COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile || bun install

COPY . .

# VITE_* are baked in at build time from .env.production (or build-args if set).
# .env.production MUST match the server's ANON_KEY — not the supabase-demo placeholder.
RUN bun run build

EXPOSE 3030

CMD ["bun", "run", "preview", "--port", "3030"]
