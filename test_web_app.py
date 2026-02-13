import requests
import time

def test_web_app_integration():
    """Test the web app integration with the speech-to-text server"""
    
    print("🧪 Testing Web App Integration")
    print("=" * 40)
    
    # Test 1: Check if speech-to-text server is running
    try:
        response = requests.get("http://localhost:5000/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Speech-to-Text Server: {data.get('status')}")
            print(f"   Model: {data.get('model')}")
        else:
            print(f"❌ Speech-to-Text Server: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Speech-to-Text Server Error: {e}")
        return False
    
    # Test 2: Test real-time recording
    try:
        response = requests.post("http://localhost:5000/start_recording", timeout=5)
        if response.status_code == 200:
            print("✅ Recording started")
            time.sleep(2)
            
            response = requests.post("http://localhost:5000/stop_recording", timeout=10)
            if response.status_code == 200:
                data = response.json()
                transcription = data.get('transcription', 'No result')
                print(f"✅ Transcription: '{transcription}'")
            else:
                print(f"❌ Stop recording: {response.status_code}")
        else:
            print(f"❌ Start recording: {response.status_code}")
    except Exception as e:
        print(f"❌ Recording Error: {e}")
    
    print("\n🎉 Web App Integration Test Complete!")
    print("📱 Web App: http://localhost:8080")
    print("🔗 Speech-to-Text Server: http://localhost:5000")
    print("\n🎯 How to use:")
    print("1. Open http://localhost:8080 in your browser")
    print("2. Click 'Test Connection' to verify server")
    print("3. Click 'Start Recording' and speak")
    print("4. Click 'Stop Recording' to see transcription")
    
    return True

if __name__ == "__main__":
    test_web_app_integration()
