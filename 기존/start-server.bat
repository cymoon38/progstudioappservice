@echo off
setlocal enabledelayedexpansion
echo ========================================
echo 로컬 개발 서버 시작
echo ========================================
echo.

REM 로컬 IP 주소 찾기
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set IP=%%a
    set IP=!IP: =!
    goto :found_ip
)
:found_ip

REM Python이 설치되어 있는지 확인
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo Python을 사용하여 서버를 시작합니다...
    echo.
    echo ========================================
    echo 모바일에서 접속 방법:
    echo ========================================
    echo 1. PC와 모바일이 같은 Wi-Fi에 연결되어 있는지 확인하세요
    echo 2. 모바일 브라우저에서 다음 주소로 접속하세요:
    echo.
    echo    http://!IP!:8000
    echo.
    echo 3. PC에서 접속: http://localhost:8000
    echo ========================================
    echo.
    echo 서버를 중지하려면 Ctrl+C를 누르세요
    echo.
    REM SPA 라우팅을 지원하는 서버 사용
    if exist server.py (
        python server.py
    ) else (
        REM server.py가 없으면 기본 서버 사용
        python -m http.server 8000 --bind 0.0.0.0
    )
) else (
    REM Node.js 확인
    node --version >nul 2>&1
    if %errorlevel% == 0 (
        echo Node.js를 사용하여 서버를 시작합니다...
        echo.
        echo ========================================
        echo 모바일에서 접속 방법:
        echo ========================================
        echo 1. PC와 모바일이 같은 Wi-Fi에 연결되어 있는지 확인하세요
        echo 2. 모바일 브라우저에서 다음 주소로 접속하세요:
        echo.
        echo    http://!IP!:8080
        echo.
        echo 3. PC에서 접속: http://localhost:8080
        echo ========================================
        echo.
        echo 서버를 중지하려면 Ctrl+C를 누르세요
        echo.
        npx --yes http-server -p 8080 -a 0.0.0.0
    ) else (
        echo Python 또는 Node.js가 설치되어 있지 않습니다.
        echo.
        echo 설치 방법:
        echo 1. Python: https://www.python.org/downloads/
        echo 2. Node.js: https://nodejs.org/
        echo.
        pause
    )
)

