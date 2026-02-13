import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import threading
import time
import numpy as np
import librosa
import torch
import noisereduce as nr
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC

# Set the port
PORT = 8086

# Global recording state
recording_active = False
recorded_audio = None

# Load Wav2Vec2 model
print("🌿 Loading Wav2Vec2 model for GreenVoice...")
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")
print("✅ Model Loaded Successfully")

class GreenVoiceTranscriber:
    def __init__(self):
        self.sample_rate = 16000
        
    def transcribe_audio_file(self, audio_file_path):
        """Transcribe audio file using Wav2Vec2"""
        try:
            print(f"🎵 Processing audio file: {audio_file_path}")
            
            # Load audio file
            audio_data, sr = librosa.load(audio_file_path, sr=self.sample_rate)
            speech = audio_data.flatten()
            print(f"✅ Audio loaded: shape={speech.shape}")
            
            # Apply noise reduction
            speech_clean = nr.reduce_noise(y=speech, sr=self.sample_rate)
            print("✅ Noise reduction complete")
            
            # Process with Wav2Vec2
            input_values = processor(
                speech_clean,
                sampling_rate=self.sample_rate,
                return_tensors="pt",
                padding=True
            ).input_values
            print("✅ Audio processed for model")

            # Get transcription
            with torch.no_grad():
                logits = model(input_values).logits

            predicted_ids = torch.argmax(logits, dim=-1)
            transcription = processor.batch_decode(predicted_ids)[0]
            
            print("\n==============================")
            print("📝 TRANSCRIPTION OUTPUT:")
            print("==============================")
            print(transcription)
            
            return transcription.strip()
            
        except Exception as e:
            print(f"❌ Error: {e}")
            return f"Error: {str(e)}"

# Initialize transcriber
transcriber = GreenVoiceTranscriber()

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class GreenVoiceHandler(http.server.SimpleHTTPRequestHandler):
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
        
        # Redirect root to the GreenVoice web app
        if self.path == '/':
            self.path = '/greenvoice_working.html'
        return super().do_GET()

    def do_POST(self):
        global recording_active, recorded_audio
        
        # Handle start recording
        if self.path == '/api/start_recording':
            recording_active = True
            recorded_audio = None
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "recording_started"}).encode())
            return
        
        # Handle stop recording
        elif self.path == '/api/stop_recording':
            recording_active = False
            
            # Simulate transcription (in real implementation, this would process audio)
            mock_transcription = "This is a sample transcription from the recording."
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "recording_stopped",
                "transcription": mock_transcription
            }).encode())
            return
        
        # Handle audio upload
        elif self.path == '/api/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                
                # Decode base64 audio
                audio_data = base64.b64decode(data['audio'])
                
                # Save to temporary file
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                    temp_file.write(audio_data)
                    temp_file_path = temp_file.name
                
                try:
                    # Transcribe audio using real model
                    transcription = transcriber.transcribe_audio_file(temp_file_path)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({
                        "transcription": transcription,
                        "status": "success"
                    }).encode())
                    return
                    
                finally:
                    # Clean up temporary file
                    try:
                        os.unlink(temp_file_path)
                    except:
                        pass
                
            except Exception as e:
                print(f"❌ Transcription Error: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
                return
        
        else:
            self.send_response(404)
            self.end_headers()
            return

print("🌿 Starting GreenVoice Web App for Jury Presentation...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Make sure the Wav2Vec2 server is running on http://localhost:5000")
print("🎯 This is a professional presentation-ready web application")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), GreenVoiceHandler) as httpd:
        print(f"✅ GreenVoice Web App running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ GreenVoice Web App stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
