#!/bin/bash

# Start Test Environment for Godot Game Milestone Submission
echo "🚀 Starting Test Environment for Milestone Submission"
echo "=" * 60

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found"
    echo "   Please install Python 3 and try again"
    exit 1
fi

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not found"
    echo "   Please install pip3 and try again"
    exit 1
fi

echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

echo "🌐 Starting Mock API Server..."
echo "   - Server will run on http://localhost:8000"
echo "   - Test login: test@example.com / password123"
echo "   - Press Ctrl+C to stop"
echo ""

# Start the mock API server
python3 mock_api_server.py