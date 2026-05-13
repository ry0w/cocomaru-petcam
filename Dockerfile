FROM node:22-alpine
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/signaling_server.js .
COPY build/web ./public
EXPOSE 8080
CMD ["node", "signaling_server.js"]
