import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import datetime

# Set the port
PORT = 3456

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Import the existing transcriber
try:
    # Import from the existing file
    import sys
    sys.path.append('.')
    
    # Try to import the components
    import numpy as np
    import librosa
    import torch
    import noisereduce as nr
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
    
    # Load the model (same as in greenvoice_fixed.py)
    print("🌿 Loading Wav2Vec2 model...")
    processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
    model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")
    print("✅ Model loaded successfully")
    
    MODEL_AVAILABLE = True
    
except Exception as e:
    print(f"⚠️  Model not available: {e}")
    MODEL_AVAILABLE = False

class ExistingModelHandler(http.server.SimpleHTTPRequestHandler):
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
            self.wfile.write(json.dumps({
                "status": "healthy",
                "model_available": MODEL_AVAILABLE
            }).encode())
            return
        
        # Redirect root to the working HTML file
        if self.path == '/':
            self.path = '/greenvoice_working.html'
        return super().do_GET()

    def transcribe_with_model(self, audio_file_path):
        """Transcribe using the existing model"""
        try:
            print(f"🎵 Processing: {audio_file_path}")
            
            # Load audio (same as in greenvoice_fixed.py)
            audio_data, sr = librosa.load(audio_file_path, sr=16000)
            speech = audio_data.flatten()
            
            # Apply noise reduction
            speech_clean = nr.reduce_noise(y=speech, sr=16000)
            
            # Process with Wav2Vec2
            input_values = processor(
                speech_clean,
                sampling_rate=16000,
                return_tensors="pt",
                padding=True
            ).input_values

            # Get transcription
            with torch.no_grad():
                logits = model(input_values).logits

            predicted_ids = torch.argmax(logits, dim=-1)
            transcription = processor.batch_decode(predicted_ids)[0]
            
            return transcription.strip()
            
        except Exception as e:
            print(f"❌ Transcription error: {e}")
            return f"Error: {str(e)}"

    def do_POST(self):
        # Handle audio upload
        if self.path == '/api/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                audio_data = base64.b64decode(data['audio'])
                audio_size = len(audio_data)
                
                print(f"🎵 Audio received: {audio_size} bytes")
                
                if MODEL_AVAILABLE:
                    # Save to temp file and transcribe
                    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                        temp_file.write(audio_data)
                        temp_file_path = temp_file.name
                    
                    try:
                        transcription = self.transcribe_with_model(temp_file_path)
                    finally:
                        try:
                            os.unlink(temp_file_path)
                        except:
                            pass
                else:
                    # Fallback - ask user to install dependencies
                    transcription = "Real transcription requires installing: pip install torch transformers librosa noisereduce"
                
                print(f"📝 Result: {transcription}")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "transcription": transcription,
                    "status": "success",
                    "audio_size": audio_size,
                    "timestamp": datetime.datetime.now().isoformat(),
                    "real_transcription": MODEL_AVAILABLE
                }).encode())
                return
                
            except Exception as e:
                print(f"❌ Error: {e}")
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": str(e),
                    "status": "error"
                }).encode())
                return
        
        else:
            self.send_response(404)
            self.end_headers()
            return

print("🌿 Starting GreenVoice with Existing Model...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print(f"🎤 Model available: {'✅ Yes' if MODEL_AVAILABLE else '❌ No - install dependencies'}")
print("🎯 Using existing Wav2Vec2 model")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), ExistingModelHandler) as httpd:
        print(f"✅ GreenVoice with Existing Model running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ GreenVoice stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
