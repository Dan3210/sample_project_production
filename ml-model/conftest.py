"""
Pytest configuration for ML model tests
"""

import os
import pytest
from unittest.mock import patch, MagicMock

@pytest.fixture(autouse=True)
def mock_aws_services():
    """Mock AWS services for testing"""
    with patch('boto3.client') as mock_client:
        # Mock CloudWatch client
        mock_cloudwatch = MagicMock()
        mock_cloudwatch.put_metric_data.return_value = {}
        mock_client.return_value = mock_cloudwatch
        yield mock_cloudwatch

@pytest.fixture(autouse=True)
def test_environment():
    """Set test environment variables"""
    os.environ['ENVIRONMENT'] = 'test'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'
    yield
    # Clean up
    if 'ENVIRONMENT' in os.environ:
        del os.environ['ENVIRONMENT']
    if 'AWS_DEFAULT_REGION' in os.environ:
        del os.environ['AWS_DEFAULT_REGION']
