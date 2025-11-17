#!/usr/bin/env python3
"""
Test script for custom LLM endpoint at llm.art-ai.me
DO NOT COMMIT THIS FILE WITH API KEYS
"""

import requests
import json

# Configuration - REPLACE WITH YOUR ACTUAL KEY
ENDPOINT = "https://llm.art-ai.me/v1/chat/completions"
API_KEY = "sk-yNFKHYOK0HLGwHj0Janw1Q"  # User key provided

def test_basic_completion():
    """Test basic chat completion"""
    print("🧪 Testing basic chat completion...")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }

    data = {
        "model": "gpt-4.1-mini",  # Using faster model for testing
        "messages": [
            {"role": "user", "content": "Say 'Hello from Helix app!' in exactly 5 words."}
        ],
        "temperature": 0.7,
        "max_tokens": 50
    }

    try:
        response = requests.post(ENDPOINT, headers=headers, json=data, timeout=10)

        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            print(f"✅ SUCCESS!")
            print(f"Response: {content}")
            print(f"Tokens used: {result['usage']['total_tokens']}")
            return True
        else:
            print(f"❌ FAILED!")
            print(f"Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ EXCEPTION: {e}")
        return False

def test_conversation_analysis():
    """Test conversation analysis (like we'll use in the app)"""
    print("\n🧪 Testing conversation analysis...")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }

    conversation_text = """
    User: We need to discuss the project timeline.
    Manager: The deadline is next Friday. We should complete the API integration by Wednesday.
    User: What about testing?
    Manager: Testing should happen Thursday morning.
    """

    data = {
        "model": "gpt-4.1",  # Using more capable model for analysis
        "messages": [
            {
                "role": "system",
                "content": "You are an AI assistant that analyzes conversations and extracts key information."
            },
            {
                "role": "user",
                "content": f"""Analyze this conversation and provide:
1. A brief summary (1-2 sentences)
2. Key action items with deadlines
3. Main topics discussed

Conversation:
{conversation_text}"""
            }
        ],
        "temperature": 0.3,  # Lower temperature for more consistent analysis
        "max_tokens": 300
    }

    try:
        response = requests.post(ENDPOINT, headers=headers, json=data, timeout=15)

        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            print(f"✅ SUCCESS!")
            print(f"\n=== Analysis Result ===")
            print(content)
            print(f"\nTokens used: {result['usage']['total_tokens']}")
            return True
        else:
            print(f"❌ FAILED!")
            print(f"Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ EXCEPTION: {e}")
        return False

def test_available_models():
    """Test fetching available models"""
    print("\n🧪 Testing available models endpoint...")

    headers = {
        "Authorization": f"Bearer {API_KEY}"
    }

    try:
        response = requests.get("https://llm.art-ai.me/v1/models", headers=headers, timeout=10)

        print(f"Status Code: {response.status_code}")

        if response.status_code == 200:
            result = response.json()
            print(f"✅ SUCCESS!")
            print(f"Available models: {len(result.get('data', []))} models")

            # Print first few models
            models = result.get('data', [])[:5]
            for model in models:
                print(f"  - {model.get('id', 'unknown')}")

            return True
        else:
            print(f"❌ FAILED!")
            print(f"Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ EXCEPTION: {e}")
        return False

def main():
    print("=" * 60)
    print("Custom LLM Endpoint Test - llm.art-ai.me")
    print("=" * 60)

    results = []

    # Test 1: Basic completion
    results.append(("Basic Completion", test_basic_completion()))

    # Test 2: Conversation analysis
    results.append(("Conversation Analysis", test_conversation_analysis()))

    # Test 3: Available models
    results.append(("Available Models", test_available_models()))

    # Summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name}: {status}")

    total = len(results)
    passed = sum(1 for _, p in results if p)
    print(f"\nTotal: {passed}/{total} tests passed")

    if passed == total:
        print("\n🎉 All tests passed! Your LLM endpoint is working correctly.")
        print("You can now integrate this into the Helix app.")
    else:
        print("\n⚠️  Some tests failed. Check the errors above.")

if __name__ == "__main__":
    main()
