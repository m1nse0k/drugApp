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
    git clone [GitHub 저장소 URL]
    cd [프로젝트 디렉토리 이름]
    ```
    *   `git clone [URL]` : 원격 저장소(GitHub)의 코드를 로컬 컴퓨터로 복제합니다.
    *   `cd [디렉토리]` : 복제된 프로젝트 폴더로 이동합니다.

2.  **Docker 이미지 빌드 (APK 아티팩트 이미지 생성):**
    프로젝트 루트 디렉토리(Dockerfile이 있는 위치)에서 다음 명령어를 실행하여 멀티스테이지 빌드를 통해 APK 파일만 포함된 Docker 이미지를 빌드합니다.
    ```bash
    docker build -t 내앱이름-apk:최신 .
    ```
    *   `docker build` : Dockerfile을 기반으로 이미지를 생성하는 명령어입니다.
    *   `-t 내앱이름-apk:최신` : 생성될 이미지에 `내앱이름-apk`라는 이름과 `최신`(latest)이라는 태그를 부여합니다. 이 이미지는 빌드된 APK 파일만 포함하게 됩니다.
    *   `.` : Dockerfile이 위치한 현재 디렉토리를 빌드 컨텍스트로 사용합니다.

3.  **빌드된 APK 파일 추출:**
    생성된 `내앱이름-apk:최신` 이미지에서 APK 파일을 로컬 시스템으로 복사합니다.
    ```bash
    # 임시 컨테이너 생성 (실행은 하지 않음, APK만 담긴 이미지 기반)
    docker create --name 임시_apk_컨테이너 내앱이름-apk:최신

    # 컨테이너에서 APK 파일 복사 (Dockerfile의 최종 스테이지 경로 기준)
    # Dockerfile에서 최종 스테이지의 WORKDIR이 /apk_output 이고, 그 안에 app-release.apk로 복사했으므로:
    docker cp 임시_apk_컨테이너:/apk_output/app-release.apk ./app-release.apk

    # 임시 컨테이너 삭제
    docker rm 임시_apk_컨테이너
    ```
    *   `docker create --name 임시_apk_컨테이너 내앱이름-apk:최신` : `내앱이름-apk:최신` 이미지를 기반으로 `임시_apk_컨테이너`라는 이름의 컨테이너를 생성만 합니다.
    *   `docker cp 임시_apk_컨테이너:/apk_output/app-release.apk ./app-release.apk` : `임시_apk_컨테이너` 내부의 `/apk_output/app-release.apk` 경로에서 `app-release.apk` 파일을 현재 로컬 디렉토리로 복사합니다.
    *   `docker rm 임시_apk_컨테이너` : 사용이 끝난 임시 컨테이너를 삭제합니다.

### 애플리케이션 시연 (Android 기준)

1.  Android Studio를 실행하고 AVD Manager를 통해 에뮬레이터를 시작하거나, 개발자 모드가 활성화된 실제 Android 기기를 PC에 연결합니다.
2.  터미널에서 추출한 `app-release.apk` 파일이 있는 디렉토리로 이동합니다.
3.  다음 ADB(Android Debug Bridge) 명령어를 사용하여 APK를 설치하고 실행합니다.
    ```bash
    # 에뮬레이터/기기에 APK 설치
    adb install app-release.apk
    ```
    *   설치 후에는 에뮬레이터/기기의 앱 서랍에서 아이콘을 클릭하여 앱을 실행하고 시연할 수 있습니다.

### 사용된 주요 Docker 기능

*   **멀티스테이지 빌드 (Multi-stage Builds)**:
    *   **빌더 스테이지 (Builder Stage)**: Flutter SDK 및 빌드 도구가 포함된 환경(`instrumentisto/flutter:3.29.2`)에서 실제 APK를 빌드합니다.
    *   **최종 아티팩트 스테이지 (Final Artifact Stage)**: 매우 가벼운 베이스 이미지(`scratch`)를 사용하여 빌더 스테이지에서 생성된 APK 파일만 복사하여 최종 이미지를 만듭니다. 이를 통해 최종 이미지 크기를 대폭 줄일 수 있습니다.
    *   `COPY --from=builder`: 이전 스테이지의 결과물을 다음 스테이지로 복사하는 핵심 구문입니다.
*   **베이스 이미지 (Base Image)**: `FROM instrumentisto/flutter:3.29.2` 및 `FROM scratch`
*   **작업 디렉토리 (WORKDIR)**: 각 스테이지의 작업 공간을 정의합니다.
*   **파일 복사 (COPY)**: 로컬 파일을 이미지로 가져오거나, 스테이지 간 파일을 복사합니다.
*   **명령 실행 (RUN)**: 이미지 빌드 중 의존성 설치 및 앱 빌드 명령을 실행합니다.
*   **레이어 캐싱 (Layer Caching)**: `pubspec.yaml` 변경 시에만 의존성을 다시 설치하도록 하여 빌드 시간을 최적화합니다.
*   **이미지 태깅 (Image Tagging)**: `-t` 옵션으로 이미지에 사람이 읽기 쉬운 이름과 버전을 부여합니다.