import sounddevice as sd
import numpy as np
import librosa
import torch
import noisereduce as nr
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
import wave
from flask import Flask, request, jsonify
from flask_cors import CORS
import tempfile
import threading
import queue
import time
import os

# Recording parameters
SAMPLE_RATE = 16000   # wav2vec2 expects 16kHz

print("Loading Wav2Vec2 model...")

# Use the Wav2Vec2 model from your speech.ipynb
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")

print("Model Loaded Successfully ✅")

class Wav2Vec2Service:
    def __init__(self):
        self.audio_queue = queue.Queue()
        self.is_recording = False
        self.recording_thread = None
        
    def transcribe_audio(self, audio_data):
        """Transcribe audio using your working speech.ipynb code"""
        try:
            # Ensure audio is in right format
            if len(audio_data.shape) > 1:
                audio_data = audio_data.mean(axis=1)
            
            print("🧠 Processing with Wav2Vec2...")
            
            # Apply noise reduction (from speech.ipynb)
            speech_clean = nr.reduce_noise(y=audio_data, sr=SAMPLE_RATE)
            
            # Process with Wav2Vec2 (from speech.ipynb)
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
        print("🎙️ Starting real-time recording...")
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
            print("✅ Recording started...")
            
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
        
        # Collect recorded audio (from speech.ipynb)
        audio_data = []
        while not self.audio_queue.empty():
            audio_data.append(self.audio_queue.get())
        
        if not audio_data:
            return "No audio recorded"
        
        speech = np.concatenate(audio_data, axis=0).flatten()
        return self.transcribe_audio(speech)

# Initialize Wav2Vec2 service
wav2vec2_service = Wav2Vec2Service()

# Flask app
app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    return jsonify({
        "service": "Speech-to-Text API",
        "status": "running",
        "model": "Wav2Vec2",
        "features": [
            "Real-time audio recording",
            "Noise reduction",
            "File transcription"
        ],
        "endpoints": {
            "/": "Home",
            "/health": "Health check",
            "/transcribe": "Main transcription endpoint",
            "/transcribe_file": "Upload file transcription",
            "/start_recording": "Start real-time recording",
            "/stop_recording": "Stop and transcribe"
        }
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "device": "cuda" if torch.cuda.is_available() else "cpu",
        "model": "Wav2Vec2",
        "features": ["real_time", "noise_reduction"]
    })

@app.route('/models')
def get_models():
    return jsonify({
        "models": ["wav2vec2-large-960h"],
        "default": "wav2vec2-large-960h",
        "features": ["real_time_processing", "noise_reduction"]
    })

@app.route('/transcribe', methods=['POST'])
def transcribe():
    """Main transcription endpoint"""
    try:
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
            
        file = request.files['audio']
        if file.filename == '':
            return jsonify({"error": "No file selected"}), 400
        
        # Get parameters
        model_name = request.form.get('model', 'wav2vec2-large-960h')
        language = request.form.get('language', 'en')
        
        print(f"🎯 Processing with model: {model_name}")
        
        # Save temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
            file.save(tmp_file.name)
            tmp_file_path = tmp_file.name
        
        try:
            # Load audio file
            audio_data, sr = librosa.load(tmp_file_path, sr=SAMPLE_RATE)
            
            # Transcribe using your working Wav2Vec2 code
            transcription = wav2vec2_service.transcribe_audio(audio_data)
            
            return jsonify({
                "text": transcription,
                "model": model_name,
                "language": language,
                "features": ["wav2vec2", "noise_reduction"]
            })
            
        finally:
            # Clean up
            if os.path.exists(tmp_file_path):
                os.unlink(tmp_file_path)
                
    except Exception as e:
        return jsonify({"error": f"Transcription error: {str(e)}"}), 500

@app.route('/transcribe_file', methods=['POST'])
def transcribe_file():
    """Transcribe uploaded audio file"""
    try:
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
        
        file = request.files['audio']
        if file.filename == '':
            return jsonify({"error": "No file selected"}), 400
        
        print(f"📁 Received file: {file.filename}")
        
        # Save temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
            file.save(tmp_file.name)
            tmp_file_path = tmp_file.name
        
        try:
            # Load and transcribe
            audio_data, sr = librosa.load(tmp_file_path, sr=SAMPLE_RATE)
            transcription = wav2vec2_service.transcribe_audio(audio_data)
            
            return jsonify({
                "transcription": transcription,
                "model": "Wav2Vec2 Large 960h",
                "sample_rate": sr
            })
            
        finally:
            # Clean up
            if os.path.exists(tmp_file_path):
                os.unlink(tmp_file_path)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/start_recording', methods=['POST'])
def start_recording():
    """Start real-time recording"""
    try:
        wav2vec2_service.start_real_time_recording()
        return jsonify({
            "status": "recording_started",
            "message": "Wav2Vec2 recording started. Speak now!",
            "features": ["wav2vec2", "noise_reduction"]
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stop_recording', methods=['POST'])
def stop_recording():
    """Stop recording and get transcription"""
    try:
        transcription = wav2vec2_service.stop_real_time_recording()
        return jsonify({
            "status": "recording_stopped",
            "transcription": transcription,
            "model": "Wav2Vec2 Large 960h"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream_transcribe', methods=['POST'])
def stream_transcribe():
    """Handle streaming audio data"""
    try:
        data = request.get_json()
        
        if 'audio_data' not in data:
            return jsonify({"error": "No audio data provided"}), 400
        
        # For streaming, we'll use a simple response for now
        return jsonify({
            "transcription": "Wav2Vec2 streaming transcription active!",
            "timestamp": time.time(),
            "model": "Wav2Vec2 Large 960h"
        })
    
    except Exception as e:
        return jsonify({"error": f"Streaming error: {str(e)}"}), 500

if __name__ == '__main__':
    print("🚀 Starting Speech-to-Text Server...")
    print("🎤 Features: Real-time transcription for hearing impaired")
    print("📱 Available endpoints:")
    print("   POST /transcribe - Main transcription")
    print("   POST /transcribe_file - Upload file")
    print("   POST /start_recording - Start recording")
    print("   POST /stop_recording - Stop and transcribe")
    print("   GET  /health - Health check")
    print(f"🔗 Server running on: http://localhost:5000")
    print("✅ Ready for Speech-to-Text App!")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
