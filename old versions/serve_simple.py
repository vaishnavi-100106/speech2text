import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import datetime

# Set the port
PORT = 5555

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class SimpleGreenVoiceHandler(http.server.SimpleHTTPRequestHandler):
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
        # Handle API health check
        if self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
            return
        
        # Redirect root to the working HTML file
        if self.path == '/':
            self.path = '/greenvoice_working.html'
        return super().do_GET()

    def do_POST(self):
        # Handle audio upload with simple processing
        if self.path == '/api/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                
                # Get audio info
                audio_data = base64.b64decode(data['audio'])
                audio_size = len(audio_data)
                
                # Simple mock transcription based on audio size
                if audio_size > 10000:
                    transcription = f"Audio received ({audio_size} bytes). This appears to be a valid audio recording. In a full implementation, this would be processed by a speech-to-text model."
                else:
                    transcription = f"Short audio received ({audio_size} bytes). Please speak for longer when recording."
                
                print(f"🎵 Audio processed: {audio_size} bytes")
                print(f"📝 Transcription: {transcription}")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "transcription": transcription,
                    "status": "success",
                    "audio_size": audio_size,
                    "timestamp": datetime.datetime.now().isoformat()
                }).encode())
                return
                
            except Exception as e:
                print(f"❌ Error processing audio: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": f"Processing error: {str(e)}",
                    "status": "error"
                }).encode())
                return
        
        else:
            self.send_response(404)
            self.end_headers()
            return

print("🌿 Starting Simple GreenVoice Web App...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Microphone recording enabled (no ML dependencies)")
print("🎯 Perfect for testing microphone functionality")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), SimpleGreenVoiceHandler) as httpd:
        print(f"✅ Simple GreenVoice running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ Simple GreenVoice stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
