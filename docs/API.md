# ML Sentiment Analysis API Documentation

## Overview

The ML Sentiment Analysis API provides endpoints for analyzing text sentiment using a keyword-based machine learning model. The API is containerized and deployed on AWS ECS with auto-scaling capabilities.

## Base URL

```
http://<ALB_DNS_NAME>/
```

## Authentication

Currently, no authentication is required. In production, consider implementing API keys or OAuth.

## Endpoints

### Health Check

**GET** `/health`

Check the health status of the API service.

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

### Root Endpoint

**GET** `/`

Get API information and available endpoints.

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
      "body": {"texts": ["string1", "string2", ...]},
      "description": "Predict sentiment of multiple texts"
    }
  }
}
```

### Single Text Prediction

**POST** `/predict`

Predict the sentiment of a single text input.

**Request Body:**
```json
{
  "text": "This is a great product!"
}
```

**Response:**
```json
{
  "prediction": {
    "sentiment": "positive",
    "confidence": 0.8,
    "positive_words": 1,
    "negative_words": 0
  },
  "input_text": "This is a great product!",
  "model_version": "1.0.0"
}
```

**Example:**
```bash
curl -X POST http://your-alb-dns/predict \
  -H 'Content-Type: application/json' \
  -d '{"text": "This is a great product!"}'
```

### Batch Prediction

**POST** `/batch-predict`

Predict sentiment for multiple texts in a single request.

**Request Body:**
```json
{
  "texts": [
    "This is great!",
    "This is terrible!",
    "This is okay."
  ]
}
```

**Response:**
```json
{
  "results": [
    {
      "index": 0,
      "prediction": {
        "sentiment": "positive",
        "confidence": 0.8,
        "positive_words": 1,
        "negative_words": 0
      },
      "input_text": "This is great!"
    },
    {
      "index": 1,
      "prediction": {
        "sentiment": "negative",
        "confidence": 0.8,
        "positive_words": 0,
        "negative_words": 1
      },
      "input_text": "This is terrible!"
    },
    {
      "index": 2,
      "prediction": {
        "sentiment": "neutral",
        "confidence": 0.5,
        "positive_words": 0,
        "negative_words": 0
      },
      "input_text": "This is okay."
    }
  ],
  "total_texts": 3,
  "model_version": "1.0.0"
}
```

**Example:**
```bash
curl -X POST http://your-alb-dns/batch-predict \
  -H 'Content-Type: application/json' \
  -d '{"texts": ["Great!", "Terrible!", "Okay."]}'
```

### Metrics

**GET** `/metrics`

Get model metrics and performance statistics.

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

## Sentiment Analysis Model

### Model Type
Keyword-based sentiment analysis using predefined positive and negative word dictionaries.

### Supported Sentiments
- **Positive**: Text containing positive sentiment words
- **Negative**: Text containing negative sentiment words  
- **Neutral**: Text with no clear sentiment or mixed sentiment

### Confidence Score
- Range: 0.0 to 1.0
- Based on the ratio of sentiment words to total sentiment words
- Higher values indicate stronger confidence in the prediction

### Positive Keywords
```
good, great, excellent, amazing, wonderful, fantastic, awesome, brilliant, 
outstanding, perfect, love, like, happy, pleased, satisfied, impressed, recommend
```

### Negative Keywords
```
bad, terrible, awful, horrible, disappointing, hate, dislike, angry, frustrated, 
annoyed, poor, worst, useless, broken, failed, error, problem, issue
```

## Error Handling

### HTTP Status Codes

- **200 OK**: Successful request
- **400 Bad Request**: Invalid input or missing required fields
- **404 Not Found**: Endpoint not found
- **405 Method Not Allowed**: HTTP method not allowed for endpoint
- **500 Internal Server Error**: Server error

### Error Response Format

```json
{
  "error": "Error type",
  "message": "Detailed error message"
}
```

### Common Errors

1. **Missing Text Field**:
   ```json
   {
     "error": "Missing required field: text"
   }
   ```

2. **Empty Text**:
   ```json
   {
     "error": "Text must be a non-empty string"
   }
   ```

3. **Text Too Long**:
   ```json
   {
     "error": "Text too long. Maximum 1000 characters allowed."
   }
   ```

4. **Too Many Texts in Batch**:
   ```json
   {
     "error": "Too many texts. Maximum 100 texts allowed."
   }
   ```

## Rate Limits

Currently, no rate limits are implemented. In production, consider implementing:
- Per-IP rate limiting
- API key-based rate limiting
- Request throttling

## Monitoring

### Health Monitoring
- Health check endpoint: `/health`
- ALB health checks every 30 seconds
- Container health checks every 30 seconds

### Metrics
- Custom CloudWatch metrics for predictions, errors, and text length
- ECS service metrics (CPU, memory, task count)
- ALB metrics (request count, response time, error rates)

### Logging
- Application logs in CloudWatch Logs
- Structured JSON logging
- Error tracking and alerting

## Performance

### Response Times
- Typical response time: < 100ms
- Batch processing: < 500ms for 100 texts
- Health check: < 50ms

### Throughput
- Designed for high availability with auto-scaling
- Can handle concurrent requests
- Load balanced across multiple ECS tasks

## Security

### Network Security
- VPC with private subnets for ECS tasks
- Security groups with least privilege access
- HTTPS termination at ALB (when configured)

### Data Privacy
- No persistent storage of input text
- Logs may contain request data (configure as needed)
- Consider data encryption in transit and at rest

## Examples

### Python Client

```python
import requests
import json

# API base URL
BASE_URL = "http://your-alb-dns"

# Single prediction
def predict_sentiment(text):
    response = requests.post(
        f"{BASE_URL}/predict",
        json={"text": text}
    )
    return response.json()

# Batch prediction
def batch_predict(texts):
    response = requests.post(
        f"{BASE_URL}/batch-predict",
        json={"texts": texts}
    )
    return response.json()

# Example usage
result = predict_sentiment("This is amazing!")
print(f"Sentiment: {result['prediction']['sentiment']}")
print(f"Confidence: {result['prediction']['confidence']}")
```

### JavaScript Client

```javascript
// Single prediction
async function predictSentiment(text) {
    const response = await fetch('http://your-alb-dns/predict', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: text })
    });
    return await response.json();
}

// Example usage
predictSentiment("This is great!")
    .then(result => {
        console.log(`Sentiment: ${result.prediction.sentiment}`);
        console.log(`Confidence: ${result.prediction.confidence}`);
    });
```

## Support

For issues or questions:
1. Check the health endpoint first
2. Review CloudWatch logs
3. Check the deployment documentation
4. Contact the development team
