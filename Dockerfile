# Stage 1: Install dependencies
FROM node:18-alpine AS deps

RUN apk add --no-cache libc6-compat
RUN npm install -g pnpm

WORKDIR /apps

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Stage 2: Build the application
FROM deps AS builder

WORKDIR /apps

COPY . .

# Explicitly copy data to a shared directory
RUN mkdir /shared && cp -r . /shared
RUN pnpm install

# Stage 3: Create the production image
FROM node:18-alpine AS runner

RUN npm install -g pnpm

WORKDIR /apps

ENV NODE_ENV development

RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

# Copy data from the shared directory
COPY --from=builder --chown=nextjs:nodejs /shared /apps

# Force cache invalidation by touching a file
RUN touch /somefile

RUN chown -R nextjs:nodejs /apps

USER nextjs
RUN pnpm install
EXPOSE 3000

CMD pnpm run dev
