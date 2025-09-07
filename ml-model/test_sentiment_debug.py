"""
Quick test to debug sentiment analysis
"""

from app import model

def test_sentiment_debug():
    test_cases = [
        "This is great!",
        "This is terrible!",
        "This is okay.",
        "I love this product!",
        "This is awful and terrible!"
    ]
    
    for text in test_cases:
        result = model.predict(text)
        print(f"Text: '{text}'")
        print(f"Result: {result}")
        print("-" * 50)

if __name__ == "__main__":
    test_sentiment_debug()
