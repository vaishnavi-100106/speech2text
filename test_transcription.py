import torch
import numpy as np
from transformers import Wav2Vec2Processor, Wav2Vec2ForCTC

# Test with exact notebook logic
SAMPLE_RATE = 16000

print("Loading model...")
processor = Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h")
model = Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h")
print("Model loaded")

# Create test audio (similar to notebook recording)
# Simulate a simple speech pattern
test_audio = np.random.randn(16000 * 3)  # 3 seconds of random speech-like audio
test_audio = test_audio / np.max(np.abs(test_audio)) * 0.1  # Normalize

print(f"Test audio shape: {test_audio.shape}")
print(f"Test audio range: {np.min(test_audio):.4f} to {np.max(test_audio):.4f}")

# Process exactly like notebook
input_values = processor(test_audio, sampling_rate=SAMPLE_RATE, return_tensors="pt", padding=True)
print(f"Input values type: {type(input_values)}")
print(f"Input values shape: {input_values.shape if hasattr(input_values, 'shape') else 'no shape'}")

with torch.no_grad():
    logits = model(input_values).logits
    print(f"Logits shape: {logits.shape}")
    print(f"Logits range: {logits.min().item():.2f} to {logits.max().item():.2f}")

predicted_ids = torch.argmax(logits, dim=-1)
print(f"Predicted IDs shape: {predicted_ids.shape}")
print(f"First 20 IDs: {predicted_ids[0][:20] if hasattr(predicted_ids, '__getitem__') else 'no ids'}")

try:
    transcription = processor.batch_decode(predicted_ids)[0]
    print(f"Transcription: '{transcription}'")
except Exception as e:
    print(f"Decode error: {e}")
    transcription = "DECODE ERROR"

# Test with different audio
test_audio2 = np.sin(2 * np.pi * 440 * np.arange(16000) / 16000) * 0.5  # 440Hz tone
input_values2 = processor(test_audio2, sampling_rate=SAMPLE_RATE, return_tensors="pt", padding=True)

with torch.no_grad():
    logits2 = model(input_values2).logits
    predicted_ids2 = torch.argmax(logits2, dim=-1)
    try:
        transcription2 = processor.batch_decode(predicted_ids2)[0]
        print(f"Tone transcription: '{transcription2}'")
    except Exception as e:
        print(f"Tone decode error: {e}")
        transcription2 = "DECODE ERROR"
