# Multi-platform build support for ARM64 and AMD64
# Docker automatically selects the correct platform based on the host

# ---- Dependencies (ALL) ----
FROM node:25-alpine AS deps
WORKDIR /app

# Install ALL dependencies (including devDependencies) for the build stage
COPY package*.json ./
# Use npm ci for faster, more reliable builds from package-lock.json
# Skip prepare script which runs husky (not needed in production)
RUN npm ci --legacy-peer-deps --ignore-scripts

# ---- Production Dependencies ----
FROM node:25-alpine AS prod-deps
WORKDIR /app

# Install only production dependencies for the final image
COPY package*.json ./
RUN npm ci --legacy-peer-deps --omit=dev --ignore-scripts

# ---- Prisma Generate ----
FROM node:25-alpine AS prisma
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY prisma ./prisma

# Generate Prisma client
RUN npx prisma generate

# ---- Builder ----
FROM node:25-alpine AS builder
WORKDIR /app
ENV NODE_ENV=production
# Ensure DEVELOPMENT is not set so Next.js creates standalone output
ENV DEVELOPMENT=

# Accept git commit SHA as build argument
ARG GIT_COMMIT_SHA=unknown
ENV GIT_COMMIT_SHA=$GIT_COMMIT_SHA

# Copy ALL node_modules from deps stage (includes dev dependencies)
COPY --from=deps /app/node_modules ./node_modules
# Copy generated Prisma client
COPY --from=prisma /app/node_modules/.prisma ./node_modules/.prisma

# Copy source files
COPY . ./

# Build the application
RUN npm run build

# ---- Runner ----
FROM node:25-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Add user and group as per Next.js recommendation
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy Prisma schema and generated client for runtime
COPY --from=prisma --chown=nextjs:nodejs /app/prisma ./prisma
COPY --from=prisma --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=prod-deps --chown=nextjs:nodejs /app/node_modules/@prisma ./node_modules/@prisma

USER nextjs

EXPOSE 3000
ENV PORT=3000

CMD ["node", "server.js"]