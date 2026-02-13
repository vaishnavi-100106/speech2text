import http.server
import socketserver
import webbrowser
import os
import json
import base64
import datetime
import tempfile
import traceback

PORT = 5555

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# ==============================
# LOAD ML LIBRARIES
# ==============================

try:
    import numpy as np
    import librosa
    import torch
    from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC

    print("🌿 Loading Wav2Vec2 model...")
    processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-base-960h")
    model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-base-960h")
    model.eval()   # IMPORTANT
    print("✅ Model loaded successfully")

    MODEL_LOADED = True

except Exception as e:
    print(f"⚠️ Model loading failed: {e}")
    MODEL_LOADED = False


# ==============================
# SERVER HANDLER
# ==============================

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

    # ==============================
    # TRANSCRIPTION FUNCTION
    # ==============================

    def transcribe_audio(self, audio_bytes):

        if not MODEL_LOADED:
            return "Model not loaded."

        try:
            print("\n🎵 Starting transcription process...")

            # Save temporary WebM file
            with tempfile.NamedTemporaryFile(suffix='.webm', delete=False) as temp_file:
                temp_file.write(audio_bytes)
                temp_path = temp_file.name

            try:
                # Load audio and resample to 16kHz
                speech, sr = librosa.load(temp_path, sr=16000, mono=True)
                print(f"✅ Audio loaded | Shape: {speech.shape} | Sample Rate: {sr}")

                if len(speech) == 0:
                    return "No audio detected."

                # Check amplitude
                max_amp = np.max(np.abs(speech))
                print(f"🔊 Max amplitude: {max_amp}")

                if max_amp < 0.01:
                    return "Audio too quiet. Please speak louder."

                # Normalize audio
                speech = speech / max_amp
                print("✅ Audio normalized")

                # Convert to model input
                inputs = processor(
                    speech,
                    sampling_rate=16000,
                    return_tensors="pt"
                )

                print("🧠 Running Wav2Vec2 model...")

                with torch.no_grad():
                    logits = model(inputs.input_values).logits

                predicted_ids = torch.argmax(logits, dim=-1)
                transcription = processor.decode(predicted_ids[0])

                print(f"🎉 Raw transcription: '{transcription}'")

                if transcription.strip() == "":
                    return "No speech detected."

                return transcription.strip()

            finally:
                try:
                    os.unlink(temp_path)
                    print("🗑️ Temporary file removed")
                except:
                    pass

        except Exception as e:
            print("❌ Transcription error:", e)
            traceback.print_exc()
            return f"Error: {str(e)}"

    # ==============================
    # ROUTES
    # ==============================

    def do_GET(self):

        if self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "healthy",
                "model_loaded": MODEL_LOADED
            }).encode())
            return

        if self.path == '/':
            self.path = '/greenvoice_working.html'

        return super().do_GET()

    def do_POST(self):

        if self.path == '/api/transcribe':

            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)

            try:
                data = json.loads(post_data.decode('utf-8'))
                audio_data = base64.b64decode(data['audio'])

                print(f"\n🎵 Audio received: {len(audio_data)} bytes")

                if MODEL_LOADED:
                    transcription = self.transcribe_audio(audio_data)
                else:
                    transcription = "Model not loaded."

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()

                self.wfile.write(json.dumps({
                    "transcription": transcription,
                    "status": "success",
                    "timestamp": datetime.datetime.now().isoformat()
                }).encode())

            except Exception as e:
                print("❌ POST error:", e)
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": str(e)
                }).encode())

        else:
            self.send_response(404)
            self.end_headers()


# ==============================
# START SERVER
# ==============================

print("\n🌿 Starting GreenVoice...")
print(f"📱 Open: http://localhost:{PORT}")
print("🎤 Speak clearly into microphone")
print("⏹️ Press Ctrl+C to stop\n")

try:
    with socketserver.TCPServer(("", PORT), GreenVoiceHandler) as httpd:
        print(f"✅ Server running at http://localhost:{PORT}")
        webbrowser.open(f"http://localhost:{PORT}")
        httpd.serve_forever()

except KeyboardInterrupt:
    print("\n⏹️ GreenVoice stopped by user")

except Exception as e:
    print("❌ Server failed:", e)
