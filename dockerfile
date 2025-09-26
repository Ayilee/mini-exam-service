# Lightweight Node runtime
FROM node:20-alpine

# Workdir
WORKDIR /app

# Install deps (prod only)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy app
COPY . .

# App listens on 3000
EXPOSE 3000

# Start
CMD ["node", "server.js"]
