import http.server
import socketserver
import webbrowser
import os
import json
import base64
import datetime

# Set the port
PORT = 8000

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class SimpleWorkingHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        print(f"GET request for: {self.path}")
        
        # Handle API health check
        if self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({"status": "healthy"}).encode()
            self.wfile.write(response)
            print("Health check responded")
            return
        
        # Redirect root to the working HTML file
        if self.path == '/':
            self.path = '/greenvoice_working.html'
            print(f"Redirecting to: {self.path}")
        
        # Try to serve the file
        try:
            return super().do_GET()
        except Exception as e:
            print(f"Error serving file: {e}")
            self.send_response(404)
            self.end_headers()
            return

    def do_POST(self):
        print(f"POST request for: {self.path}")
        
        # Handle audio upload
        if self.path == '/api/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                audio_data = base64.b64decode(data['audio'])
                audio_size = len(audio_data)
                
                print(f"🎵 Audio received: {audio_size} bytes")
                
                # Simple demo transcription
                transcription = f"Audio received ({audio_size} bytes). Demo mode active."
                
                print(f"📝 Transcription: {transcription}")
                
                response = json.dumps({
                    "transcription": transcription,
                    "status": "success",
                    "audio_size": audio_size,
                    "timestamp": datetime.datetime.now().isoformat()
                }).encode()
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(response)
                return
                
            except Exception as e:
                print(f"❌ Error: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
                return
        
        else:
            print(f"404 for POST: {self.path}")
            self.send_response(404)
            self.end_headers()
            return

print("🌿 Starting Simple Working GreenVoice...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Microphone recording enabled")
print("🎯 Simple demo mode")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), SimpleWorkingHandler) as httpd:
        print(f"✅ Server running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ Server stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
