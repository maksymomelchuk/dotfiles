#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "elevenlabs",
#     "python-dotenv",
# ]
# ///

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

def main():
    """
    ElevenLabs Turbo v2.5 TTS Script
    
    Uses ElevenLabs' Turbo v2.5 model for fast, high-quality text-to-speech.
    Accepts optional text prompt as command-line argument.
    
    Usage:
    - ./eleven_turbo_tts.py                    # Uses default text
    - ./eleven_turbo_tts.py "Your custom text" # Uses provided text
    
    Features:
    - Fast generation (optimized for real-time use)
    - High-quality voice synthesis
    - Stable production model
    - Cost-effective for high-volume usage
    """
    
    # Load environment variables
    load_dotenv()
    
    # Get API key from environment
    api_key = os.getenv('ELEVENLABS_API_KEY')
    if not api_key:
        print("❌ Error: ELEVENLABS_API_KEY not found in environment variables")
        print("Please add your ElevenLabs API key to .env file:")
        print("ELEVENLABS_API_KEY=your_api_key_here")
        sys.exit(1)
    
    try:
        from elevenlabs.client import ElevenLabs
        from elevenlabs import save
        
        # Initialize client
        elevenlabs = ElevenLabs(api_key=api_key)
        
        print("🎙️  ElevenLabs Turbo v2.5 TTS")
        print("=" * 40)
        
        # Get text from command line argument or use default
        if len(sys.argv) > 1:
            text = " ".join(sys.argv[1:])  # Join all arguments as text
        else:
            text = "The first move is what sets everything in motion."
        
        print(f"🎯 Text: {text}")
        print("🔊 Generating and playing...")
        
        try:
            # Get voice_id from environment or use default
            voice_id = os.getenv('ELEVENLABS_VOICE_ID', 'iP95p4xoKVk53GoZ742B')  # Default: Rachel voice
            
            # Generate audio
            audio = elevenlabs.text_to_speech.convert(
                text=text,
                voice_id=voice_id,
                model_id="eleven_turbo_v2_5",
                output_format="mp3_44100_128",
            )
            
            # Save to temporary file and play using system command
            import tempfile
            with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp_file:
                save(audio, tmp_file.name)
                tmp_path = tmp_file.name
            
            # Play audio using system command (works on macOS, Linux, Windows)
            import platform
            if platform.system() == 'Darwin':  # macOS
                subprocess.run(['afplay', tmp_path], check=False)
            elif platform.system() == 'Linux':
                subprocess.run(['mpg123', '-q', tmp_path] if subprocess.run(['which', 'mpg123'], capture_output=True).returncode == 0 
                              else ['paplay', tmp_path], check=False)
            elif platform.system() == 'Windows':
                subprocess.run(['start', tmp_path], shell=True, check=False)
            
            # Clean up temp file
            os.unlink(tmp_path)
            
            print("✅ Playback complete!")
            
        except Exception as e:
            print(f"❌ Error: {e}")
        
        
    except ImportError:
        print("❌ Error: elevenlabs package not installed")
        print("This script uses UV to auto-install dependencies.")
        print("Make sure UV is installed: https://docs.astral.sh/uv/")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()