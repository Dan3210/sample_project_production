"""
ML Model API Service
A simple sentiment analysis API using a pre-trained model
"""

import os
import logging
from typing import Dict, Any
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# AWS Services - Initialize with error handling
cloudwatch = None
try:
    cloudwatch = boto3.client(
        "cloudwatch", region_name=os.getenv("AWS_DEFAULT_REGION", "us-east-2")
    )
except Exception as e:
    logger.warning(f"CloudWatch not available: {e}")


class SentimentAnalyzer:
    """Simple sentiment analysis model"""

    def __init__(self):
        # Simple keyword-based sentiment analysis
        self.positive_words = {
            "good",
            "great",
            "excellent",
            "amazing",
            "wonderful",
            "fantastic",
            "awesome",
            "brilliant",
            "outstanding",
            "perfect",
            "love",
            "like",
            "happy",
            "pleased",
            "satisfied",
            "impressed",
            "recommend",
        }

        self.negative_words = {
            "bad",
            "terrible",
            "awful",
            "horrible",
            "disappointing",
            "hate",
            "dislike",
            "angry",
            "frustrated",
            "annoyed",
            "poor",
            "worst",
            "useless",
            "broken",
            "failed",
            "error",
            "problem",
            "issue",
        }

    def predict(self, text: str) -> Dict[str, Any]:
        """Predict sentiment of the given text"""
        if not text or not isinstance(text, str):
            return {
                "sentiment": "neutral",
                "confidence": 0.0,
                "error": "Invalid input text",
            }

        text_lower = text.lower()
        # Remove punctuation and split into words
        import string

        text_clean = text_lower.translate(str.maketrans("", "", string.punctuation))
        words = text_clean.split()

        positive_count = sum(1 for word in words if word in self.positive_words)
        negative_count = sum(1 for word in words if word in self.negative_words)

        total_sentiment_words = positive_count + negative_count

        if total_sentiment_words == 0:
            sentiment = "neutral"
            confidence = 0.5
        elif positive_count > negative_count:
            sentiment = "positive"
            confidence = positive_count / total_sentiment_words
        elif negative_count > positive_count:
            sentiment = "negative"
            confidence = negative_count / total_sentiment_words
        else:
            sentiment = "neutral"
            confidence = 0.5

        return {
            "sentiment": sentiment,
            "confidence": round(confidence, 3),
            "positive_words": positive_count,
            "negative_words": negative_count,
        }


# Initialize the model
model = SentimentAnalyzer()


def put_metric(metric_name: str, value: float, unit: str = "Count"):
    """Put custom metric to CloudWatch"""
    if cloudwatch is None:
        logger.debug(f"CloudWatch not available, skipping metric: {metric_name}")
        return

    try:
        cloudwatch.put_metric_data(
            Namespace="MLModel/SentimentAnalysis",
            MetricData=[
                {
                    "MetricName": metric_name,
                    "Value": value,
                    "Unit": unit,
                    "Dimensions": [
                        {
                            "Name": "Environment",
                            "Value": os.getenv("ENVIRONMENT", "dev"),
                        }
                    ],
                }
            ],
        )
    except ClientError as e:
        logger.error(f"Failed to put metric {metric_name}: {e}")


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    return (
        jsonify(
            {
                "status": "healthy",
                "service": "ml-sentiment-analysis",
                "version": "1.0.0",
                "environment": os.getenv("ENVIRONMENT", "dev"),
            }
        ),
        200,
    )


@app.route("/predict", methods=["POST"])
def predict_sentiment():
    """Predict sentiment of input text"""
    try:
        data = request.get_json()

        if not data or "text" not in data:
            return jsonify({"error": "Missing required field: text"}), 400

        text = data["text"]

        # Validate input
        if not isinstance(text, str) or len(text.strip()) == 0:
            return jsonify({"error": "Text must be a non-empty string"}), 400

        if len(text) > 1000:
            return (
                jsonify(
                    {"error": "Text too long. Maximum 1000 characters allowed."}
                ),
                400,
            )

        # Make prediction
        result = model.predict(text)

        # Log metrics
        put_metric("Predictions", 1)
        put_metric("TextLength", len(text), "Count")

        # Log prediction result
        logger.info(
            f"Prediction made: {result['sentiment']} "
            f"(confidence: {result['confidence']})"
        )

        return (
            jsonify(
                {
                    "prediction": result,
                    "input_text": text,
                    "model_version": "1.0.0",
                }
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error in prediction: {str(e)}")
        put_metric("Errors", 1)

        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route("/batch-predict", methods=["POST"])
def batch_predict():
    """Predict sentiment for multiple texts"""
    try:
        data = request.get_json()

        if not data or "texts" not in data:
            return jsonify({"error": "Missing required field: texts"}), 400

        texts = data["texts"]

        if not isinstance(texts, list):
            return jsonify({"error": "Texts must be a list"}), 400

        if len(texts) > 100:
            return (
                jsonify({"error": "Too many texts. Maximum 100 texts allowed."}),
                400,
            )

        results = []
        for i, text in enumerate(texts):
            if not isinstance(text, str):
                results.append({"index": i, "error": "Text must be a string"})
            else:
                prediction = model.predict(text)
                results.append(
                    {"index": i, "prediction": prediction, "input_text": text}
                )

        # Log metrics
        put_metric("BatchPredictions", 1)
        put_metric("BatchSize", len(texts), "Count")

        logger.info(f"Batch prediction made for {len(texts)} texts")

        return (
            jsonify(
                {
                    "results": results,
                    "total_texts": len(texts),
                    "model_version": "1.0.0",
                }
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error in batch prediction: {str(e)}")
        put_metric("Errors", 1)

        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route("/metrics", methods=["GET"])
def get_metrics():
    """Get model metrics and statistics"""
    try:
        # This would typically query a database or cache
        # For now, return static metrics
        return (
            jsonify(
                {
                    "model_info": {
                        "name": "Sentiment Analysis Model",
                        "version": "1.0.0",
                        "type": "keyword-based",
                        "supported_languages": ["en"],
                    },
                    "performance": {
                        "total_predictions": 0,  # Would be tracked in production
                        "average_confidence": 0.0,
                        "accuracy": 0.0,
                    },
                    "endpoints": {
                        "predict": "/predict",
                        "batch_predict": "/batch-predict",
                        "health": "/health",
                    },
                }
            ),
            200,
        )

    except Exception as e:
        logger.error(f"Error getting metrics: {str(e)}")
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route("/", methods=["GET"])
def root():
    """Root endpoint with API information"""
    return (
        jsonify(
            {
                "service": "ML Sentiment Analysis API",
                "version": "1.0.0",
                "status": "running",
                "environment": os.getenv("ENVIRONMENT", "dev"),
                "endpoints": {
                    "health": "/health",
                    "predict": "/predict",
                    "batch_predict": "/batch-predict",
                    "metrics": "/metrics",
                },
                "documentation": {
                    "predict": {
                        "method": "POST",
                        "body": {"text": "string"},
                        "description": "Predict sentiment of a single text",
                    },
                    "batch_predict": {
                        "method": "POST",
                        "body": {"texts": ["string1", "string2"]},
                        "description": "Predict sentiment of multiple texts",
                    },
                },
            }
        ),
        200,
    )


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return (
        jsonify(
            {
                "error": "Endpoint not found",
                "message": "The requested endpoint does not exist",
            }
        ),
        404,
    )


@app.errorhandler(405)
def method_not_allowed(error):
    """Handle 405 errors"""
    return (
        jsonify(
            {
                "error": "Method not allowed",
                "message": "The HTTP method is not allowed for this endpoint",
            }
        ),
        405,
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    debug = os.getenv("ENVIRONMENT", "dev") == "dev"

    logger.info(f"Starting ML Sentiment Analysis API on port {port}")
    logger.info(f"Environment: {os.getenv('ENVIRONMENT', 'dev')}")

    app.run(host="0.0.0.0", port=port, debug=debug)
