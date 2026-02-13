import http.server
import socketserver
import webbrowser
import os
import json
import base64
import tempfile
import subprocess
import numpy as np
import librosa
import torch
import noisereduce as nr
import traceback
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

# Disable Flask logging
logging.getLogger('werkzeug').setLevel(logging.ERROR)

PORT = 8089
SAMPLE_RATE = 16000

print("🌿 Loading Wav2Vec2 model...")

processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")

model.eval()

print("✅ Model Loaded Successfully")


def convert_to_wav(input_path):
    """Convert any audio file to 16kHz mono WAV using FFmpeg"""
    output_path = input_path + "_converted.wav"

    command = [
        "ffmpeg",
        "-y",
        "-i", input_path,
        "-ar", "16000",
        "-ac", "1",
        output_path
    ]

    subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    return output_path


class GreenVoiceTranscriber:
    def __init__(self):
        self.sample_rate = SAMPLE_RATE

    def transcribe_audio_array(self, audio_data):
        try:
            print(f"🎵 Processing audio array: shape={audio_data.shape}")

            speech_clean = nr.reduce_noise(y=audio_data, sr=self.sample_rate)
            print("✅ Noise reduction complete")

            input_values = processor(
                speech_clean,
                sampling_rate=self.sample_rate,
                return_tensors="pt",
                padding=True
            ).input_values

            with torch.no_grad():
                logits = model(input_values).logits

            predicted_ids = torch.argmax(logits, dim=-1)
            transcription = processor.batch_decode(predicted_ids)[0]

            print("📝 TRANSCRIPTION:", transcription)

            return transcription.strip()

        except Exception:
            print("❌ Transcription Error:")
            traceback.print_exc()
            return None

    def transcribe_audio_file(self, audio_file_path):
        try:
            print(f"🎵 Processing audio file: {audio_file_path}")

            # Convert to WAV if needed
            if not audio_file_path.endswith(".wav"):
                audio_file_path = convert_to_wav(audio_file_path)
                print("🔄 Converted to WAV")

            audio_data, sr = librosa.load(
                audio_file_path,
                sr=self.sample_rate,
                mono=True
            )

            print(f"✅ Audio loaded: shape={audio_data.shape}")

            return self.transcribe_audio_array(audio_data)

        except Exception:
            print("❌ Audio File Error:")
            traceback.print_exc()
            return None


transcriber = GreenVoiceTranscriber()

app = Flask(__name__)
CORS(app)


@app.route('/transcribe', methods=['POST'])
def transcribe():
    try:
        data = request.get_json()

        if not data or 'audio' not in data:
            return jsonify({"error": "No audio data provided"}), 400

        audio_bytes = base64.b64decode(data['audio'])

        file_extension = ".webm"
        if data.get("format") == "wav":
            file_extension = ".wav"

        with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as temp_file:
            temp_file.write(audio_bytes)
            temp_file_path = temp_file.name

        try:
            transcription = transcriber.transcribe_audio_file(temp_file_path)

            if transcription is None:
                return jsonify({"error": "Transcription failed"}), 500

            return jsonify({
                "transcription": transcription,
                "status": "success"
            }), 200

        finally:
            try:
                os.unlink(temp_file_path)
            except:
                pass

    except Exception:
        print("❌ API Error:")
        traceback.print_exc()
        return jsonify({"error": "Server error"}), 500


class GreenVoiceHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = '/greenvoice_standalone.html'
        return super().do_GET()

    def do_POST(self):
        if self.path == '/transcribe':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)

            with app.test_request_context(
                path='/transcribe',
                method='POST',
                data=post_data,
                headers=dict(self.headers)
            ):
                try:
                    response = app.full_dispatch_request()
                    response_data = response.get_data()

                    self.send_response(response.status_code)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(response_data)

                except Exception:
                    self.send_response(500)
                    self.end_headers()
        else:
            super().do_POST()


def run_server():
    print("🌿 Starting GreenVoice")
    print(f"📱 Open: http://localhost:{PORT}")
    print("⏹️ Press Ctrl+C to stop")

    with socketserver.TCPServer(("", PORT), GreenVoiceHandler) as httpd:
        webbrowser.open(f'http://localhost:{PORT}')
        httpd.serve_forever()


if __name__ == "__main__":
    run_server()
