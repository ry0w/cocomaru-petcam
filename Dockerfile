# ---- Stage 1: Flutter Web Build ----
FROM ghcr.io/cirruslabs/flutter:3.32.1 AS flutter-build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib/ lib/
COPY assets/ assets/
COPY web/ web/
RUN flutter build web --release

# ---- Stage 2: Node.js Production ----
FROM node:22-alpine
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/signaling_server.js .
COPY --from=flutter-build /app/build/web ./public
EXPOSE 8080
CMD ["node", "signaling_server.js"]
