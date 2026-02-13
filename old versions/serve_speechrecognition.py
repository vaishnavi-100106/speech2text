import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import datetime
import speech_recognition as sr
import wave
import io

# Set the port
PORT = 7777

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class SpeechRecognitionHandler(http.server.SimpleHTTPRequestHandler):
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

    def transcribe_audio(self, audio_data):
        """Transcribe audio using speech recognition"""
        try:
            # Initialize recognizer
            r = sr.Recognizer()
            
            # Save audio data to temporary file
            with tempfile.NamedTemporaryFile(suffix='.webm', delete=False) as temp_file:
                temp_file.write(audio_data)
                temp_file_path = temp_file.name
            
            try:
                # Use speech recognition with the audio file
                with sr.AudioFile(temp_file_path) as source:
                    audio = r.record(source)
                    
                # Try Google Speech Recognition
                try:
                    text = r.recognize_google(audio)
                    return f"Transcription: {text}"
                except sr.UnknownValueError:
                    return "Could not understand audio - please speak clearly"
                except sr.RequestError as e:
                    return f"Error with speech recognition service: {e}"
                    
            finally:
                # Clean up temporary file
                try:
                    os.unlink(temp_file_path)
                except:
                    pass
                
        except Exception as e:
            # If audio file reading fails, try to convert it
            try:
                # Try to read as different format
                audio_file = io.BytesIO(audio_data)
                with sr.AudioFile(audio_file) as source:
                    audio = r.record(source)
                    
                text = r.recognize_google(audio)
                return f"Transcription: {text}"
                
            except:
                return f"Error processing audio format: {str(e)}. Try recording again."

    def do_POST(self):
        # Handle audio upload with speech recognition
        if self.path == '/api/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                
                # Get audio data
                audio_data = base64.b64decode(data['audio'])
                audio_size = len(audio_data)
                
                print(f"🎵 Audio received: {audio_size} bytes")
                
                # Transcribe the audio
                transcription = self.transcribe_audio(audio_data)
                
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

print("🌿 Starting GreenVoice with Speech Recognition...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Microphone recording with real speech-to-text")
print("🎯 Using Google Speech Recognition API")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), SpeechRecognitionHandler) as httpd:
        print(f"✅ GreenVoice with Speech Recognition running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ GreenVoice stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
