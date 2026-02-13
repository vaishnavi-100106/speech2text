import os
import json
import base64
import tempfile
import numpy as np
import librosa
import torch
import noisereduce as nr
import sys
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import webbrowser
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC

# Set the port
PORT = 8091

# Recording parameters (EXACT from notebook)
SAMPLE_RATE = 16000

print("🌿 Loading Wav2Vec2 model for GreenVoice...")

# Try a simpler model loading approach
try:
    processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
    model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")
    print("✅ Model Loaded Successfully")
except Exception as e:
    print(f"❌ Model loading failed: {e}")
    sys.exit(1)

class GreenVoiceTranscriber:
    def __init__(self):
        self.sample_rate = SAMPLE_RATE
        
    def transcribe_audio_array(self, audio_data):
        """SIMPLIFIED transcription logic"""
        try:
            print(f"🎵 Processing audio: shape={audio_data.shape}")
            
            # Apply noise reduction
            speech_clean = nr.reduce_noise(y=audio_data, sr=self.sample_rate)
            print("✅ Noise reduction complete")
            
            # Simple processing - avoid complex transformers issues
            input_values = processor(speech_clean, sampling_rate=self.sample_rate, return_tensors="pt")
            print(f"✅ Audio processed: {input_values.shape}")
            
            # Get transcription
            with torch.no_grad():
                logits = model(input_values).logits
                predicted_ids = torch.argmax(logits, dim=-1)
                
                # Try simple decode
                try:
                    transcription = processor.batch_decode(predicted_ids)[0]
                    print(f"✅ Transcription: '{transcription}'")
                except Exception as e:
                    print(f"❌ Decode error: {e}")
                    # Fallback: return IDs as text
                    ids = predicted_ids[0].tolist()
                    transcription = f"IDs: {ids[:10]}..."  # Show first 10
                    print(f"✅ Fallback: {transcription}")
            
            return transcription.strip() if 'transcription' in locals() else transcription
            
        except Exception as e:
            print(f"❌ Error: {e}")
            return f"Error: {str(e)}"

    def transcribe_audio_file(self, audio_file_path):
        """Transcribe audio file using Wav2Vec2"""
        try:
            print(f"🎵 Processing audio file: {audio_file_path}")
            
            # Load audio file
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
        if not data or 'audio' not in data:
            print("❌ No audio data")
            return jsonify({"error": "No audio data provided"}), 400
        
        print(f"📥 Audio data received: {len(data.get('audio', ''))} chars")
        
        # Decode base64 audio
        try:
            audio_data = base64.b64decode(data['audio'])
            print(f"📥 Decoded audio: {len(audio_data)} bytes")
        except Exception as e:
            print(f"❌ Base64 decode error: {e}")
            return jsonify({"error": f"Base64 decode error: {str(e)}"}), 400
        
        # Save to temporary file
        temp_file_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                temp_file.write(audio_data)
                temp_file_path = temp_file.name
            
            # Transcribe audio
            transcription = transcriber.transcribe_audio_file(temp_file_path)
            
            return jsonify({
                "transcription": transcription,
                "status": "success"
            })
            
        except Exception as e:
            print(f"❌ Transcription error: {e}")
            return jsonify({"error": str(e)}), 500
            
        finally:
            # Clean up temporary file
            if temp_file_path:
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
        # Try to serve the HTML file from current directory
        return send_from_directory('.', 'greenvoice_standalone.html')
    except Exception as e:
        return f"Error serving file: {str(e)}", 500

def run_server():
    """Run the GreenVoice server - SIMPLE WORKING VERSION"""
    print("🌿 Starting GreenVoice - Simple Working Server")
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
