@echo off
echo 서버 연결 테스트 중...
echo.

REM 간단한 HTTP 요청 테스트
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8000' -TimeoutSec 5 -UseBasicParsing; Write-Host '서버 응답 성공!' -ForegroundColor Green; Write-Host '상태 코드:' $response.StatusCode } catch { Write-Host '서버 응답 실패:' $_.Exception.Message -ForegroundColor Red }"

echo.
echo 서버가 실행 중인지 확인하려면:
echo 1. 브라우저에서 http://localhost:8000 접속
echo 2. 모바일에서 http://192.168.219.105:8000 접속
echo.
pause



