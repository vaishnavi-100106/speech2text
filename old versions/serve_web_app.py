import http.server
import socketserver
import webbrowser
import os

# Set the port
PORT = 8080

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        # Redirect root to the web app
        if self.path == '/':
            self.path = '/web_app.html'
        return super().do_GET()

print("🚀 Starting Speech-to-Text Web App...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Make sure the Wav2Vec2 server is running on http://localhost:5000")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"✅ Server running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ Server stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
