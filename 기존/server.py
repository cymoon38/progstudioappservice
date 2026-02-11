#!/usr/bin/env python3
"""
SPA를 위한 간단한 HTTP 서버
모든 경로에 대해 index.html을 반환하여 SPA 라우팅을 지원합니다.
"""
import http.server
import socketserver
import os
from urllib.parse import urlparse

class SPAHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # CORS 헤더 추가 (모바일 접속을 위해)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_GET(self):
        # URL 파싱
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # 정적 파일 요청인지 확인 (파일 확장자가 있는 경우)
        if '.' in os.path.basename(path) and not path.endswith('/'):
            # 정적 파일이 존재하는지 확인
            file_path = path.lstrip('/')
            if os.path.exists(file_path) and os.path.isfile(file_path):
                # 정적 파일 반환
                return super().do_GET()
        
        # SPA 라우팅: 모든 경로에 대해 index.html 반환
        self.path = '/index.html'
        return super().do_GET()
    
    def log_message(self, format, *args):
        # 로그 메시지 포맷팅
        print(f"[{self.log_date_time_string()}] {args[0]}")

if __name__ == '__main__':
    PORT = 8000
    
    with socketserver.TCPServer(("0.0.0.0", PORT), SPAHTTPRequestHandler) as httpd:
        print("=" * 50)
        print("SPA 개발 서버 시작")
        print("=" * 50)
        print(f"\n서버 주소: http://0.0.0.0:{PORT}")
        print(f"로컬 접속: http://localhost:{PORT}")
        print("\n모바일에서 접속하려면:")
        print("1. PC와 모바일이 같은 Wi-Fi에 연결되어 있는지 확인")
        print("2. 모바일 브라우저에서 다음 주소로 접속:")
        print("   http://[PC의 IP 주소]:8000")
        print("\n서버를 중지하려면 Ctrl+C를 누르세요")
        print("=" * 50)
        print()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n서버를 종료합니다...")
            httpd.shutdown()



