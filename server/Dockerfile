FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production
COPY signaling_server.js .
EXPOSE 8080 8443
CMD ["node", "signaling_server.js"]
