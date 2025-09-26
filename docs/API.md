# Sentiment Analysis API Documentation

## Overview

This API provides sentiment analysis capabilities using a keyword-based approach. It analyzes text input and returns sentiment classification (positive, negative, or neutral) with confidence scores.

## Base URL

```
http://your-alb-dns-name
```

## Authentication

Currently, no authentication is required. All endpoints are publicly accessible.

## Endpoints

### 1. Health Check

**GET** `/health`

Check if the service is running and healthy.

**Response:**
```json
{
  "status": "healthy",
  "service": "ml-sentiment-analysis",
  "version": "1.0.0",
  "environment": "dev"
}
```

**Example:**
```bash
curl http://your-alb-dns/health
```

---

### 2. API Information

**GET** `/`

Get API documentation and available endpoints.

**Response:**
```json
{
  "service": "ML Sentiment Analysis API",
  "version": "1.0.0",
  "status": "running",
  "environment": "dev",
  "endpoints": {
    "health": "/health",
    "predict": "/predict",
    "batch_predict": "/batch-predict",
    "metrics": "/metrics"
  },
  "documentation": {
    "predict": {
      "method": "POST",
      "body": {"text": "string"},
      "description": "Predict sentiment of a single text"
    },
    "batch_predict": {
      "method": "POST",
      "body": {"texts": ["string1", "string2"]},
      "description": "Predict sentiment of multiple texts"
    }
  }
}
```

---

### 3. Single Text Sentiment Analysis

**POST** `/predict`

Analyze the sentiment of a single text input.

**Request Body:**
```json
{
  "text": "This product is amazing and I love it!"
}
```

**Parameters:**
- `text` (string, required): Text to analyze (max 1000 characters)

**Response:**
```json
{
  "prediction": {
    "sentiment": "positive",
    "confidence": 0.667,
    "positive_words": 2,
    "negative_words": 0
  },
  "input_text": "This product is amazing and I love it!",
  "model_version": "1.0.0"
}
```

**Response Fields:**
- `prediction.sentiment`: "positive", "negative", or "neutral"
- `prediction.confidence`: Confidence score (0.0 to 1.0)
- `prediction.positive_words`: Count of positive keywords found
- `prediction.negative_words`: Count of negative keywords found
- `input_text`: Original input text
- `model_version`: Version of the sentiment analysis model

**Example:**
```bash
curl -X POST http://your-alb-dns/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "This product is amazing and I love it!"}'
```

**Error Responses:**

**400 Bad Request** - Invalid input:
```json
{
  "error": "Missing required field: text"
}
```

**400 Bad Request** - Text too long:
```json
{
  "error": "Text too long. Maximum 1000 characters allowed."
}
```

---

### 4. Batch Sentiment Analysis

**POST** `/batch-predict`

Analyze sentiment for multiple texts in a single request.

**Request Body:**
```json
{
  "texts": [
    "Great product!",
    "Terrible service",
    "It's okay"
  ]
}
```

**Parameters:**
- `texts` (array, required): Array of texts to analyze (max 100 texts)

**Response:**
```json
{
  "results": [
    {
      "index": 0,
      "prediction": {
        "sentiment": "positive",
        "confidence": 1.0,
        "positive_words": 1,
        "negative_words": 0
      },
      "input_text": "Great product!"
    },
    {
      "index": 1,
      "prediction": {
        "sentiment": "negative",
        "confidence": 1.0,
        "positive_words": 0,
        "negative_words": 1
      },
      "input_text": "Terrible service"
    },
    {
      "index": 2,
      "prediction": {
        "sentiment": "neutral",
        "confidence": 0.5,
        "positive_words": 0,
        "negative_words": 0
      },
      "input_text": "It's okay"
    }
  ],
  "total_texts": 3,
  "model_version": "1.0.0"
}
```

**Example:**
```bash
curl -X POST http://your-alb-dns/batch-predict \
  -H "Content-Type: application/json" \
  -d '{"texts": ["Great product!", "Terrible service", "It'\''s okay"]}'
```

**Error Responses:**

**400 Bad Request** - Invalid input:
```json
{
  "error": "Missing required field: texts"
}
```

**400 Bad Request** - Too many texts:
```json
{
  "error": "Too many texts. Maximum 100 texts allowed."
}
```

---

### 5. Model Metrics

**GET** `/metrics`

Get model information and performance metrics.

**Response:**
```json
{
  "model_info": {
    "name": "Sentiment Analysis Model",
    "version": "1.0.0",
    "type": "keyword-based",
    "supported_languages": ["en"]
  },
  "performance": {
    "total_predictions": 0,
    "average_confidence": 0.0,
    "accuracy": 0.0
  },
  "endpoints": {
    "predict": "/predict",
    "batch_predict": "/batch-predict",
    "health": "/health"
  }
}
```

---

## Sentiment Analysis Model

### How It Works

The sentiment analysis model uses a keyword-based approach:

1. **Text Preprocessing**: Removes punctuation and converts to lowercase
2. **Keyword Matching**: Counts positive and negative keywords
3. **Sentiment Classification**: 
   - If positive keywords > negative keywords → "positive"
   - If negative keywords > positive keywords → "negative"
   - If equal or no keywords → "neutral"
4. **Confidence Calculation**: Based on the ratio of sentiment keywords

### Positive Keywords

- good, great, excellent, amazing, wonderful, fantastic, awesome, brilliant, outstanding, perfect, love, like, happy, pleased, satisfied, impressed, recommend

### Negative Keywords

- bad, terrible, awful, horrible, disappointing, hate, dislike, angry, frustrated, annoyed, poor, worst, useless, broken, failed, error, problem, issue

### Limitations

- **Language**: Currently supports English only
- **Context**: Does not understand context or sarcasm
- **Complexity**: Simple keyword matching may not capture nuanced sentiment
- **Accuracy**: Best suited for straightforward positive/negative sentiment

---

## Error Handling

### Common Error Codes

- **400 Bad Request**: Invalid input parameters
- **404 Not Found**: Endpoint does not exist
- **405 Method Not Allowed**: HTTP method not supported
- **500 Internal Server Error**: Server-side error

### Error Response Format

```json
{
  "error": "Error description",
  "message": "Detailed error message"
}
```

---

## Rate Limits

Currently, no rate limits are enforced. However, the service is designed to handle reasonable load through auto-scaling.

## Monitoring

The API sends metrics to CloudWatch:
- `Predictions`: Number of predictions made
- `BatchPredictions`: Number of batch predictions made
- `TextLength`: Length of input text
- `BatchSize`: Size of batch requests
- `Errors`: Number of errors encountered

---

## Examples

### Python Example

```python
import requests

# Single prediction
response = requests.post('http://your-alb-dns/predict', 
                        json={'text': 'This is amazing!'})
result = response.json()
print(f"Sentiment: {result['prediction']['sentiment']}")

# Batch prediction
response = requests.post('http://your-alb-dns/batch-predict',
                        json={'texts': ['Great!', 'Terrible!', 'Okay']})
results = response.json()
for item in results['results']:
    print(f"Text: {item['input_text']} -> {item['prediction']['sentiment']}")
```

### JavaScript Example

```javascript
// Single prediction
const response = await fetch('http://your-alb-dns/predict', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({text: 'This is amazing!'})
});
const result = await response.json();
console.log(`Sentiment: ${result.prediction.sentiment}`);

// Batch prediction
const batchResponse = await fetch('http://your-alb-dns/batch-predict', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({texts: ['Great!', 'Terrible!', 'Okay']})
});
const batchResults = await batchResponse.json();
batchResults.results.forEach(item => {
  console.log(`Text: ${item.input_text} -> ${item.prediction.sentiment}`);
});
```