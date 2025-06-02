애플리케이션 이름 : 이약뭐약?

[애플리케이션에 대한 간략한 설명]

## Docker를 사용한 빌드 및 APK 추출 방법

이 프로젝트는 Docker의 멀티스테이지 빌드 기능을 사용하여 일관된 환경에서 Flutter 애플리케이션을 빌드하고, 최종적으로 APK 파일만 포함된 경량 이미지를 생성합니다.

### 사전 요구 사항

*   [Git]
*   [Docker Desktop] 또는 Docker Engine (Linux)
*   [Android Emulator] 또는 실제 Android 기기

### 빌드 및 APK 추출 단계

1.  **프로젝트 클론:**
    ```bash
    git clone https://github.com/m1nse0k/drugApp.git
    cd [프로젝트 디렉토리 이름]
    ```

2.  **Docker 이미지 빌드 (APK 아티팩트 이미지 생성):**
    프로젝트 루트 디렉토리(Dockerfile이 있는 위치)에서 다음 명령어를 실행하여 멀티스테이지 빌드를 통해 APK 파일만 포함된 Docker 이미지를 빌드합니다.
    ```bash
    docker build -t 내앱이름-apk:1.0.0 .
    ```

3.  **빌드된 APK 파일 추출:**
    생성된 `내앱이름-apk:1.0.0` 이미지에서 APK 파일을 로컬 시스템으로 복사합니다.
    ```bash
    # 임시 컨테이너 생성 (실행은 하지 않음, APK만 담긴 이미지 기반)
    docker create --name 임시_apk_컨테이너 내앱이름-apk:1.0.0

    # 컨테이너에서 APK 파일 복사 (Dockerfile의 최종 스테이지 경로 기준)
    # Dockerfile에서 최종 스테이지의 WORKDIR이 /apk_output 이고, 그 안에 app-release.apk로 복사했으므로:
    docker cp 임시_apk_컨테이너:/apk_output/app-release.apk ./app-release.apk

    # 임시 컨테이너 삭제
    docker rm 임시_apk_컨테이너
    ```

### 애플리케이션 실행 (Android 기준)

1.  Android Studio를 실행하고 AVD Manager를 통해 에뮬레이터를 시작하거나, 개발자 모드가 활성화된 실제 Android 기기를 PC에 연결합니다.
2.  터미널에서 추출한 `app-release.apk` 파일이 있는 디렉토리로 이동합니다.
3.  다음 ADB(Android Debug Bridge) 명령어를 사용하여 APK를 설치하고 실행합니다.
    ```bash
    adb install app-release.apk
    ```

### 사용된 주요 Docker 기능

*   **멀티스테이지 빌드 (Multi-stage Builds)**:
    *   **빌더 스테이지 (Builder Stage)**: Flutter SDK 및 빌드 도구가 포함된 환경(`instrumentisto/flutter:3.29.2`)에서 실제 APK를 빌드합니다.
    *   **최종 아티팩트 스테이지 (Final Artifact Stage)**: 매우 가벼운 Linux 배포판인 `alpine:latest`를 베이스 이미지로 사용하여, 빌더 스테이지에서 생성된 APK 파일만 복사하여 최종 이미지를 만듭니다.
*   **레이어 캐싱 (Layer Caching)**: `pubspec.yaml` 변경 시에만 의존성을 다시 설치하도록 하여 빌드 시간을 최적화합니다.