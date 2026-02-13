import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import wave
import numpy as np
import librosa
import torch
import noisereduce as nr
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
from flask import Flask, request, jsonify
from flask_cors import CORS
import threading
import time
import logging

# Disable Flask logging
logging.getLogger('werkzeug').setLevel(logging.ERROR)

# Set the port
PORT = 8084

# Recording parameters
SAMPLE_RATE = 16000

print("🌿 Loading Wav2Vec2 model for GreenVoice...")

# Load Wav2Vec2 model
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")

print("✅ Model Loaded Successfully")

class GreenVoiceTranscriber:
    def __init__(self):
        self.sample_rate = SAMPLE_RATE
        
    def transcribe_audio_file(self, audio_file_path):
        """Transcribe audio file using Wav2Vec2"""
        try:
            print(f"🎵 Processing audio file: {audio_file_path}")
            
            # Load audio file with better error handling
            audio_data = None
            sr = self.sample_rate
            
            # Try different methods to load the audio
            try:
                # Method 1: Try librosa first
                audio_data, sr = librosa.load(audio_file_path, sr=self.sample_rate)
                print(f"✅ Audio loaded with librosa: shape={audio_data.shape}, duration={len(audio_data)/sr:.2f}s")
            except Exception as e:
                print(f"❌ Failed to load with librosa: {e}")
                
                try:
                    # Method 2: Try a simpler approach for webm - convert to wav using built-in tools
                    import subprocess
                    import os
                    
                    # Convert webm to wav using ffmpeg if available, otherwise skip
                    wav_file = audio_file_path.replace('.webm', '.wav')
                    try:
                        # Try to use ffmpeg (it might be in system PATH even if not in current session)
                        subprocess.run(['ffmpeg', '-i', audio_file_path, '-ar', str(self.sample_rate), '-ac', '1', wav_file], 
                                     check=True, capture_output=True)
                        print(f"✅ Converted webm to wav using ffmpeg")
                        
                        # Load the converted wav file
                        audio_data, sr = librosa.load(wav_file, sr=self.sample_rate)
                        print(f"✅ Audio loaded from converted wav: shape={audio_data.shape}")
                        
                        # Clean up temporary wav file
                        try:
                            os.unlink(wav_file)
                        except:
                            pass
                            
                    except (subprocess.CalledProcessError, FileNotFoundError):
                        print(f"❌ FFmpeg not available, trying alternative method")
                        raise Exception("FFmpeg not available for webm conversion")
                        
                except Exception as e2:
                    print(f"❌ Failed webm conversion: {e2}")
                    
                    try:
                        # Method 3: Try soundfile as last resort
                        import soundfile as sf
                        audio_data, sr = sf.read(audio_file_path)
                        if sr != self.sample_rate:
                            import scipy.signal as signal
                            audio_data = signal.resample(audio_data, int(len(audio_data) * self.sample_rate / sr))
                        print(f"✅ Audio loaded with soundfile: shape={audio_data.shape}")
                    except Exception as e3:
                        print(f"❌ Failed to load with soundfile: {e3}")
                        raise Exception(f"Could not load audio file with any method: {e}")
            
            # Check if audio is valid
            if audio_data is None or len(audio_data) == 0:
                raise Exception("Audio file is empty or corrupted")
            
            # Apply noise reduction
            try:
                speech_clean = nr.reduce_noise(y=audio_data, sr=self.sample_rate)
                print("✅ Noise reduction applied")
            except Exception as e:
                print(f"⚠️ Noise reduction failed, using original audio: {e}")
                speech_clean = audio_data
            
            # Process with Wav2Vec2
            try:
                input_values = processor(
                    speech_clean,
                    sampling_rate=self.sample_rate,
                    return_tensors="pt",
                    padding=True
                ).input_values
                print("✅ Audio processed for model")
            except Exception as e:
                raise Exception(f"Failed to process audio for model: {e}")

            # Get transcription
            try:
                with torch.no_grad():
                    logits = model(input_values).logits

                predicted_ids = torch.argmax(logits, dim=-1)
                transcription = processor.batch_decode(predicted_ids)[0]
                print(f"✅ Transcription completed: '{transcription.strip()}'")
                
                return transcription.strip()
            except Exception as e:
                raise Exception(f"Model inference failed: {e}")
            
        except Exception as e:
            error_msg = f"❌ Transcription error: {str(e)}"
            print(error_msg)
            return error_msg

# Initialize transcriber
transcriber = GreenVoiceTranscriber()

# Create Flask app
app = Flask(__name__)
CORS(app)

@app.route('/transcribe', methods=['POST'])
def transcribe():
    """Transcribe audio from web app"""
    try:
        data = request.get_json()
        
        if not data or 'audio' not in data:
            return jsonify({"error": "No audio data provided"}), 400
        
        # Decode base64 audio
        audio_data = base64.b64decode(data['audio'])
        
        # Save to temporary file
        file_extension = '.wav' if data.get('format') == 'wav' else '.webm'
        with tempfile.NamedTemporaryFile(suffix=file_extension, delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_file_path = temp_file.name
        
        try:
            # Transcribe the audio
            transcription = transcriber.transcribe_audio_file(temp_file_path)
            
            return jsonify({
                "transcription": transcription,
                "status": "success"
            })
            
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_file_path)
            except:
                pass
                
    except Exception as e:
        print(f"❌ API Error: {e}")
        return jsonify({"error": str(e)}), 500

class GreenVoiceHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        # Redirect root to the GreenVoice web app
        if self.path == '/':
            self.path = '/greenvoice_standalone.html'
        return super().do_GET()

    def do_POST(self):
        # Handle transcription requests
        if self.path == '/transcribe':
            # Create a simple WSGI environment for Flask
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Create Flask request context
            with app.test_request_context(
                path='/transcribe',
                method='POST',
                data=post_data,
                headers=dict(self.headers)
            ):
                try:
                    response = app.full_dispatch_request()
                    response_data = response.get_data()
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(response_data)
                except Exception as e:
                    self.send_response(500)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            super().do_POST()

def run_server():
    """Run the GreenVoice server"""
    print("🌿 Starting GreenVoice - Integrated Speech-to-Text App")
    print(f"📱 Open your browser and go to: http://localhost:{PORT}")
    print("🎤 Built-in Wav2Vec2 speech-to-text included!")
    print("🎯 Perfect for jury presentation - everything in one place!")
    print("✅ No connection issues - everything is integrated!")
    print("⏹️ Press Ctrl+C to stop the server")
    
    try:
        with socketserver.TCPServer(("", PORT), GreenVoiceHandler) as httpd:
            print(f"✅ GreenVoice running at http://localhost:{PORT}")
            
            # Open browser automatically
            webbrowser.open(f'http://localhost:{PORT}')
            
            # Start the server
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n⏹️ GreenVoice stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")

if __name__ == "__main__":
    run_server()
