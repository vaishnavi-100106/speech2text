import http.server
import socketserver
import webbrowser
import os
import json
import base64
import datetime
import tempfile
import traceback

# Set the port
PORT = 5555

# Change to the directory containing the HTML file
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Try to import the ML libraries
try:
    import numpy as np
    import librosa
    import torch
    import noisereduce as nr
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
    
    # Load the model
    print("🌿 Loading Wav2Vec2 model...")
    processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
    model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")
    print("✅ Model loaded successfully")
    
    MODEL_LOADED = True
    
except Exception as e:
    print(f"⚠️  Model loading failed: {e}")
    MODEL_LOADED = False

class WebMFixHandler(http.server.SimpleHTTPRequestHandler):
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

    def transcribe_audio(self, audio_data):
        """Transcribe audio using Wav2Vec2 with WebM handling"""
        if not MODEL_LOADED:
            return "Model not loaded. Please check installation."
        
        try:
            print("🎵 Starting transcription process...")
            
            # Save as WebM file (correct format)
            with tempfile.NamedTemporaryFile(suffix='.webm', delete=False) as temp_file:
                temp_file.write(audio_data)
                temp_file_path = temp_file.name
                print(f"📁 WebM audio saved to: {temp_file_path}")
            
            try:
                print("📖 Loading WebM audio with librosa...")
                # Load WebM audio directly (librosa can handle WebM)
                audio_data_loaded, sr = librosa.load(temp_file_path, sr=16000, mono=True)
                speech = audio_data_loaded.flatten()
                print(f"✅ Audio loaded: shape={speech.shape}, sample_rate={sr}")
                
                print("🔧 Applying noise reduction...")
                # Apply noise reduction
                # speech_clean = nr.reduce_noise(y=speech, sr=16000)
                print("✅ Noise reduction complete")
                
                print("🤖 Processing with Wav2Vec2...")
                # Process with Wav2Vec2
                input_values = processor(
                    speech_clean,
                    sampling_rate=16000,
                    return_tensors="pt",
                    padding=True
                ).input_values
                print("✅ Audio processed for model")

                print("🧠 Getting transcription...")
                # Get transcription
                with torch.no_grad():
                    logits = model(input_values).logits

                predicted_ids = torch.argmax(logits, dim=-1)
                transcription = processor.batch_decode(predicted_ids)[0]
                
                print(f"🎉 Raw transcription: '{transcription}'")
                return transcription.strip()
                
            finally:
                # Clean up temporary file
                try:
                    os.unlink(temp_file_path)
                    print("🗑️  Temp file cleaned up")
                except:
                    pass
                    
        except Exception as e:
            error_msg = f"Transcription error: {str(e)}"
            print(f"❌ {error_msg}")
            traceback.print_exc()
            return error_msg

    def do_GET(self):
        # Handle API health check
        if self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "healthy",
                "model_loaded": MODEL_LOADED
            }).encode())
            return
        
        # Redirect root to the working HTML file
        if self.path == '/':
            self.path = '/greenvoice_working.html'
        return super().do_GET()

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
                
                if MODEL_LOADED:
                    print("📝 Using real speech-to-text...")
                    transcription = self.transcribe_audio(audio_data)
                else:
                    transcription = f"Audio processed ({audio_size} bytes). Model not loaded."
                
                print(f"📝 Result: {transcription}")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "transcription": transcription,
                    "status": "success",
                    "audio_size": audio_size,
                    "timestamp": datetime.datetime.now().isoformat(),
                    "real_transcription": MODEL_LOADED
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

print("🌿 Starting GreenVoice with WebM Fix...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Microphone recording with WebM support")
print("🎯 Direct WebM processing (no FFmpeg needed)")
print("⏹️ Press Ctrl+C to stop the server")

try:
    with socketserver.TCPServer(("", PORT), WebMFixHandler) as httpd:
        print(f"✅ GreenVoice with WebM Fix running at http://localhost:{PORT}")
        
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Start the server
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n⏹️ GreenVoice stopped by user")
except Exception as e:
    print(f"❌ Error starting server: {e}")
