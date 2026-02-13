import torch
import numpy as np
import sys

print("Creating simple test...")

# Test if basic tensor operations work
test_tensor = torch.randn(1, 1000)
print(f"Test tensor shape: {test_tensor.shape}")
print(f"Test tensor mean: {test_tensor.mean():.4f}")
print(f"Test tensor max: {test_tensor.max():.4f}")

# Test argmax
result = torch.argmax(test_tensor, dim=-1)
print(f"Argmax result: {result}")

# Test if we can create a simple transcription
test_ids = torch.randint(0, 50, (1, 100))  # Random token IDs
print(f"Test IDs: {test_ids}")

# Simple token to text mapping (very basic)
token_map = {
    0: " ", 1: "A", 2: "B", 3: "C", 4: "D", 5: "E",
    10: "J", 11: "K", 12: "L", 15: "O", 20: "T",
    25: "Z", 30: "HELLO"
}

result_text = "".join([token_map.get(id.item(), "?") for id in test_ids[0]])
print(f"Mock transcription: '{result_text}'")

print("✅ Basic test completed successfully!")
print("The issue is NOT with basic PyTorch operations.")
print("The issue is with the transformers library or model loading.")
