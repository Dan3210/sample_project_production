"""
Tests for the ML Sentiment Analysis API
"""

import pytest
import json
from app import app, model

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['service'] == 'ml-sentiment-analysis'

def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['service'] == 'ML Sentiment Analysis API'
    assert 'endpoints' in data

def test_predict_positive_sentiment(client):
    """Test positive sentiment prediction"""
    response = client.post('/predict', 
                          json={'text': 'This is a great product!'})
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['prediction']['sentiment'] == 'positive'
    assert data['prediction']['confidence'] > 0.5

def test_predict_negative_sentiment(client):
    """Test negative sentiment prediction"""
    response = client.post('/predict', 
                          json={'text': 'This is terrible and awful!'})
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['prediction']['sentiment'] == 'negative'
    assert data['prediction']['confidence'] > 0.5

def test_predict_neutral_sentiment(client):
    """Test neutral sentiment prediction"""
    response = client.post('/predict', 
                          json={'text': 'The weather is okay today.'})
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert data['prediction']['sentiment'] == 'neutral'

def test_predict_missing_text(client):
    """Test prediction with missing text"""
    response = client.post('/predict', json={})
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data

def test_predict_empty_text(client):
    """Test prediction with empty text"""
    response = client.post('/predict', json={'text': ''})
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data

def test_predict_long_text(client):
    """Test prediction with text too long"""
    long_text = 'a' * 1001
    response = client.post('/predict', json={'text': long_text})
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data

def test_batch_predict(client):
    """Test batch prediction"""
    texts = [
        'This is great!',
        'This is terrible!',
        'This is okay.'
    ]
    
    response = client.post('/batch-predict', json={'texts': texts})
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert len(data['results']) == 3
    assert data['total_texts'] == 3

def test_batch_predict_missing_texts(client):
    """Test batch prediction with missing texts"""
    response = client.post('/batch-predict', json={})
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data

def test_batch_predict_too_many_texts(client):
    """Test batch prediction with too many texts"""
    texts = ['text'] * 101
    response = client.post('/batch-predict', json={'texts': texts})
    assert response.status_code == 400
    
    data = json.loads(response.data)
    assert 'error' in data

def test_metrics_endpoint(client):
    """Test metrics endpoint"""
    response = client.get('/metrics')
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert 'model_info' in data
    assert 'performance' in data

def test_404_error(client):
    """Test 404 error handling"""
    response = client.get('/nonexistent')
    assert response.status_code == 404
    
    data = json.loads(response.data)
    assert 'error' in data

def test_405_error(client):
    """Test 405 error handling"""
    response = client.get('/predict')
    assert response.status_code == 405
    
    data = json.loads(response.data)
    assert 'error' in data

def test_model_predict():
    """Test model prediction directly"""
    # Test positive
    result = model.predict('This is great!')
    assert result['sentiment'] == 'positive'
    assert result['confidence'] > 0
    
    # Test negative
    result = model.predict('This is terrible!')
    assert result['sentiment'] == 'negative'
    assert result['confidence'] > 0
    
    # Test neutral
    result = model.predict('This is okay.')
    assert result['sentiment'] == 'neutral'
    
    # Test empty text
    result = model.predict('')
    assert result['sentiment'] == 'neutral'
    assert 'error' in result
