# 1단계: 빌드 환경 (Builder Stage)
# Flutter SDK와 빌드 도구가 있는 이미지를 사용하여 APK를 빌드합니다.
FROM instrumentisto/flutter:3.29.2 AS builder

# 작업 디렉토리를 /app으로 설정합니다.
WORKDIR /app

# 1. 의존성 파일만 먼저 복사하여 Docker 빌드 캐시를 활용합니다.
#    pubspec.yaml 또는 pubspec.lock 파일이 변경되지 않으면 'flutter pub get' 단계를 건너뛸 수 있습니다.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# 2. 프로젝트의 나머지 전체 소스 코드를 작업 디렉토리로 복사합니다.
COPY . .

# 3. Android 앱 (APK)을 릴리즈 모드로 빌드합니다.
RUN flutter build apk --release

# 2단계: 최종 아티팩트 이미지 (Final Artifact Stage)
# 빌드된 APK 파일만 포함하는 매우 가벼운 이미지를 만듭니다.
FROM alpine:latest

# APK 파일이 저장될 작업 디렉토리 (컨테이너 내부 경로)
WORKDIR /apk_output

# 빌더 스테이지(/app/build/app/outputs/flutter-apk/app-release.apk)에서
# 빌드된 APK 파일을 현재 스테이지의 작업 디렉토리로 복사합니다.
COPY --from=builder /app/build/app/outputs/flutter-apk/app-release.apk ./app-release.apk

CMD ["sh"]