import os
import json
import base64
import tempfile
import numpy as np
import librosa
import torch
import noisereduce as nr
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
from flask import Flask, request, jsonify
from flask_cors import CORS
import webbrowser

# Set the port
PORT = 8090

# Recording parameters (EXACT from notebook)
SAMPLE_RATE = 16000

print("🌿 Loading Wav2Vec2 model for GreenVoice...")

# Load Wav2Vec2 model (EXACT from notebook)
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")

print("✅ Model Loaded Successfully")

class GreenVoiceTranscriber:
    def __init__(self):
        self.sample_rate = SAMPLE_RATE
        
    def transcribe_audio_array(self, audio_data):
        """EXACT notebook transcription logic"""
        try:
            print(f"🎵 Processing audio: shape={audio_data.shape}")
            
            # EXACT notebook: Apply noise reduction
            speech_clean = nr.reduce_noise(y=audio_data, sr=self.sample_rate)
            print("✅ Noise reduction complete")
            
            # EXACT notebook: Process with Wav2Vec2
            input_values = processor(
                speech_clean,
                sampling_rate=self.sample_rate,
                return_tensors="pt",
                padding=True
            ).input_values
            print("✅ Audio processed for model")

            # EXACT notebook: Get transcription
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

    def transcribe_audio_file(self, audio_file_path):
        """Transcribe audio file using Wav2Vec2"""
        try:
            print(f"🎵 Processing audio file: {audio_file_path}")
            
            # EXACT notebook: Load audio file
            audio_data, sr = librosa.load(audio_file_path, sr=self.sample_rate)
            speech = audio_data.flatten()
            print(f"✅ Audio loaded: shape={speech.shape}")
            
            # Use array method
            return self.transcribe_audio_array(speech)
            
        except Exception as e:
            print(f"❌ Error: {e}")
            return f"Error: {str(e)}"

# Initialize transcriber
transcriber = GreenVoiceTranscriber()

# Create Flask app
app = Flask(__name__)
CORS(app)

@app.route('/transcribe', methods=['POST'])
def transcribe():
    """Transcribe audio from web app"""
    try:
        print("📥 Received transcription request")
        
        data = request.get_json()
        print("📥 Data keys:", data.keys() if data else "No data")
        
        if not data or 'audio' not in data:
            print("❌ No audio data in request")
            return jsonify({"error": "No audio data provided"}), 400
        
        # Debug: Check audio data
        audio_b64 = data['audio']
        print(f"📥 Audio data length: {len(audio_b64)} characters")
        
        # Decode base64 audio
        try:
            audio_data = base64.b64decode(audio_b64)
            print(f"📥 Decoded audio size: {len(audio_data)} bytes")
        except Exception as e:
            print(f"❌ Base64 decode error: {e}")
            return jsonify({"error": f"Base64 decode error: {str(e)}"}), 400
        
        # Save to temporary file
        file_extension = '.wav' if data.get('format') == 'wav' else '.webm'
        with tempfile.NamedTemporaryFile(suffix=file_extension, delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_file_path = temp_file.name
        
        print(f"📥 Saved temp file: {temp_file_path}")
        
        try:
            # Transcribe audio
            transcription = transcriber.transcribe_audio_file(temp_file_path)
            
            response_data = {
                "transcription": transcription,
                "status": "success"
            }
            print(f"📥 Sending response: {response_data}")
            
            return jsonify(response_data)
            
        except Exception as e:
            print(f"❌ Transcription error: {e}")
            return jsonify({"error": str(e)}), 500
            
        finally:
            # Clean up temporary file
            try:
                os.unlink(temp_file_path)
                print(f"📥 Cleaned temp file: {temp_file_path}")
            except:
                pass
                
    except Exception as e:
        print(f"❌ API Error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/')
def index():
    """Serve the main page"""
    try:
        return app.send_static_file('greenvoice_standalone.html')
    except Exception as e:
        return f"Error serving file: {str(e)}", 500

def run_server():
    """Run the GreenVoice server - FLASK ONLY"""
    print("🌿 Starting GreenVoice - Clean Flask Server")
    print(f"📱 Open your browser and go to: http://localhost:{PORT}")
    print("🎤 Built-in Wav2Vec2 speech-to-text included!")
    print("⏹️ Press Ctrl+C to stop the server")
    
    try:
        # Open browser automatically
        webbrowser.open(f'http://localhost:{PORT}')
        
        # Run Flask app directly
        app.run(host="0.0.0.0", port=PORT, debug=False)
        
    except KeyboardInterrupt:
        print("\n⏹️ GreenVoice stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")

if __name__ == "__main__":
    run_server()
