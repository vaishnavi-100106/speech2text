import http.server
import socketserver
import webbrowser
import os
import json
import threading
import queue
import time
import tempfile
import wave
import numpy as np
import sounddevice as sd
import librosa
import torch
import noisereduce as nr
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

# Disable Flask logging
logging.getLogger('werkzeug').setLevel(logging.ERROR)

# Set the port
PORT = 8080

# Recording parameters
SAMPLE_RATE = 16000

print("🌿 Loading Wav2Vec2 model for GreenVoice...")

# Load Wav2Vec2 model
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")

print("✅ Model Loaded Successfully")

class GreenVoiceService:
    def __init__(self):
        self.audio_queue = queue.Queue()
        self.is_recording = False
        self.recording_thread = None
        
    def transcribe_audio(self, audio_data):
        """Transcribe audio using Wav2Vec2"""
        try:
            # Ensure audio is in right format
            if len(audio_data.shape) > 1:
                audio_data = audio_data.mean(axis=1)
            
            # Apply noise reduction
            speech_clean = nr.reduce_noise(y=audio_data, sr=SAMPLE_RATE)
            
            # Process with Wav2Vec2
            input_values = processor(
                speech_clean,
                sampling_rate=SAMPLE_RATE,
                return_tensors="pt",
                padding=True
            ).input_values

            with torch.no_grad():
                logits = model(input_values).logits

            predicted_ids = torch.argmax(logits, dim=-1)
            transcription = processor.batch_decode(predicted_ids)[0]
            
            return transcription.strip()
            
        except Exception as e:
            print(f"❌ Transcription error: {e}")
            return f"Error: {str(e)}"
    
    def start_real_time_recording(self):
        """Start real-time recording"""
        print("🎙️ Starting recording...")
        self.is_recording = True
        self.audio_queue.queue.clear()
        
        def callback(indata, frames, time_info, status):
            if self.is_recording:
                self.audio_queue.put(indata.copy())
        
        try:
            self.stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                channels=1,
                callback=callback
            )
            self.stream.start()
            print("✅ Recording started")
            
        except Exception as e:
            print(f"❌ Recording error: {e}")
            self.is_recording = False
    
    def stop_real_time_recording(self):
        """Stop recording and get transcription"""
        print("⏹️ Stopping recording...")
        self.is_recording = False
        
        try:
            if hasattr(self, 'stream'):
                self.stream.stop()
                self.stream.close()
        except:
            pass
        
        # Collect recorded audio
        audio_data = []
        while not self.audio_queue.empty():
            audio_data.append(self.audio_queue.get())
        
        if not audio_data:
            return "No audio recorded"
        
        speech = np.concatenate(audio_data, axis=0).flatten()
        return self.transcribe_audio(speech)

# Initialize GreenVoice service
greenvoice_service = GreenVoiceService()

# Create Flask app
app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    return jsonify({
        "service": "GreenVoice Speech-to-Text",
        "status": "running",
        "model": "Wav2Vec2",
        "features": [
            "Real-time audio recording",
            "Noise reduction",
            "File transcription"
        ]
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "device": "cuda" if torch.cuda.is_available() else "cpu",
        "model": "Wav2Vec2",
        "features": ["real_time", "noise_reduction"]
    })

@app.route('/start_recording', methods=['POST'])
def start_recording():
    """Start real-time recording"""
    try:
        greenvoice_service.start_real_time_recording()
        return jsonify({
            "status": "recording_started",
            "message": "Recording started. Speak now!"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stop_recording', methods=['POST'])
def stop_recording():
    """Stop recording and get transcription"""
    try:
        transcription = greenvoice_service.stop_real_time_recording()
        return jsonify({
            "status": "recording_stopped",
            "transcription": transcription,
            "model": "Wav2Vec2"
        })
    except Exception as e:
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
            self.path = '/greenvoice_web_app.html'
        return super().do_GET()

    def do_POST(self):
        # Handle API calls
        if self.path.startswith('/api/'):
            # Convert to Flask app
            environ = {
                'REQUEST_METHOD': 'POST',
                'CONTENT_TYPE': self.headers.get('Content-Type'),
                'CONTENT_LENGTH': self.headers.get('Content-Length'),
                'wsgi.input': self.rfile,
            }
            
            # Create a simple WSGI environment
            def start_response(status, headers):
                self.send_response(int(status.split()[0]))
                for header, value in headers:
                    self.send_header(header, value)
                self.end_headers()
            
            # Route to Flask app
            if self.path == '/api/start_recording':
                response = app(environ, start_response)
            elif self.path == '/api/stop_recording':
                response = app(environ, start_response)
            elif self.path == '/api/health':
                response = app(environ, start_response)
            else:
                self.send_response(404)
                self.end_headers()
                return
        else:
            super().do_POST()

def run_flask_app():
    """Run Flask app in a separate thread"""
    app.run(host='127.0.0.1', port=5001, debug=False, use_reloader=False)

print("🌿 Starting GreenVoice Web App with Integrated Speech-to-Text...")
print(f"📱 Open your browser and go to: http://localhost:{PORT}")
print("🎤 Built-in Wav2Vec2 speech-to-text included!")
print("🎯 Perfect for jury presentation - everything in one place!")
print("⏹️ Press Ctrl+C to stop the server")

# Start Flask app in background thread
flask_thread = threading.Thread(target=run_flask_app, daemon=True)
flask_thread.start()

# Give Flask time to start
time.sleep(2)

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
