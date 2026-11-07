FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app/mobile
COPY mobile/ .
RUN flutter pub get
RUN flutter build web --release --dart-define=APP_STYLE=flat

FROM nginx:alpine
COPY --from=build /app/mobile/build/web /usr/share/nginx/html
COPY mobile/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 10000
CMD ["nginx", "-g", "daemon off;"]
