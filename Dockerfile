# 1단계: Flutter SDK가 설치된 베이스 이미지를 사용합니다.
# cirrusci/flutter는 Flutter 공식 CI에서 사용하는 이미지로, 다양한 버전 태그가 있습니다. (예: stable, beta, dev, 3.10.0 등)
FROM instrumentisto/flutter:3.29.2 AS builder

# 작업 디렉토리를 /app으로 설정합니다.
WORKDIR /app

# 1. pubspec.yaml 파일을 먼저 복사하여 의존성을 설치합니다.
#    이렇게 하면 pubspec.yaml이 변경되지 않는 한 Docker 빌드 캐시를 활용하여 'flutter pub get' 단계를 건너뛸 수 있습니다.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# 2. 프로젝트의 나머지 파일들을 작업 디렉토리로 복사합니다.
#    assets 폴더도 여기에 포함되어야 합니다. pubspec.yaml에 assets 경로가 잘 명시되어 있는지 확인하세요.
COPY . .
# 3. Android 앱 (APK)을 빌드합니다.
#    --release 플래그는 릴리즈 모드로 빌드합니다.
#    (iOS 빌드는 macOS 환경이 필요하며, Docker만으로는 복잡합니다. 여기서는 APK 빌드에 집중합니다.)
RUN flutter clean
RUN flutter pub get
RUN flutter build apk --release
# 만약 웹 빌드가 필요하다면: RUN flutter build web --release

# (선택 사항) 빌드된 APK를 쉽게 찾을 수 있도록 특정 위치로 옮길 수 있습니다.
# RUN mkdir -p /app/apk_output && \
#     cp build/app/outputs/flutter-apk/app-release.apk /app/apk_output/

# 이 Dockerfile은 주로 빌드용이므로, 실행 명령(CMD 또는 ENTRYPOINT)은 필수는 아닙니다.
# 만약 컨테이너를 실행시켜 특정 작업을 하려면 CMD를 추가할 수 있습니다.
# CMD ["/bin/bash"] # 컨테이너 실행 시 bash 셸을 띄움 (디버깅용)