"""
Debug script to test sentiment analysis
"""

from app import model

def test_sentiment():
    test_cases = [
        "This is great!",
        "This is terrible!",
        "This is okay.",
        "I love this product!",
        "This is awful and terrible!"
    ]
    
    for text in test_cases:
        result = model.predict(text)
        words = text.lower().split()
        positive_count = sum(1 for word in words if word in model.positive_words)
        negative_count = sum(1 for word in words if word in model.negative_words)
        
        print(f"Text: '{text}'")
        print(f"Words: {words}")
        print(f"Positive words found: {positive_count}")
        print(f"Negative words found: {negative_count}")
        print(f"Result: {result}")
        print("-" * 50)

if __name__ == "__main__":
    test_sentiment()
