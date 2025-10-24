#!/bin/bash

# Start Full Game Environment with Docker
echo "🚀 Starting Full Game Environment"
echo "=" * 60

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not found"
    echo "   Please install Docker and try again"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is required but not found"
    echo "   Please install Docker Compose and try again"
    exit 1
fi

echo "🐳 Starting game services with Docker..."
echo "   - Database: PostgreSQL on port 5432"
echo "   - API: FastAPI server on port 8000"
echo "   - Test login: test@example.com / password123"
echo "   - Press Ctrl+C to stop all services"
echo ""

# Start the full game stack
docker-compose up --build