# 「シングルスレッド」で動くサーバ
from http.server import HTTPServer, SimpleHTTPRequestHandler

server_address = ('', 8080)
httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
print("シングルスレッドサーバー起動中...")
httpd.serve_forever()