#!/usr/bin/env python3
"""
Mock API Server for Godot Game Testing
Simple Flask server for milestone submission - no database required
Implements essential endpoints for character management, inventory, and market
"""

from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import jwt
import uuid
import time
from datetime import datetime, timedelta
import json

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Secret key for JWT (use a real secret in production)
SECRET_KEY = "test-secret-key-for-milestone"

# In-memory storage (for testing only)
users = {
    "test@example.com": {
        "id": 1,
        "email": "test@example.com",
        "password": "password123",  # In real app, this would be hashed
        "created_at": "2024-01-01T00:00:00Z"
    }
}

characters = {}  # user_id -> [character_list]
inventories = {}  # character_id -> inventory_data
market_data = {
    "prices": {
        "pistol": 100,
        "rifle": 250,
        "bandage": 5,
        "energy_bar": 10,
        "armor": 150
    },
    "stock": {
        "pistol": 5,
        "rifle": 3,
        "bandage": 20,
        "energy_bar": 15,
        "armor": 8
    },
    "events": []
}

def generate_jwt(user_id):
    """Generate JWT token for user"""
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(hours=24)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def verify_jwt(token):
    """Verify JWT token and return user_id"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def get_auth_header():
    """Extract JWT from Authorization header"""
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header.split(' ')[1]
    return None

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "message": "Mock API Server for Godot Game",
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints": [
            "POST /auth/login",
            "POST /auth/logout",
            "GET /auth/verify",
            "GET /characters",
            "POST /characters",
            "DELETE /characters/<id>",
            "GET /inventory/<character_id>",
            "POST /inventory/save",
            "GET /market/prices",
            "POST /market/events"
        ]
    })

# Authentication Endpoints
@app.route('/auth/login', methods=['POST'])
def login():
    """User login endpoint"""
    data = request.get_json()
    email = data.get('email', '').lower()
    password = data.get('password', '')

    if not email or not password:
        return jsonify({"success": False, "error": "Email and password required"}), 400

    user = users.get(email)
    if not user or user['password'] != password:
        return jsonify({"success": False, "error": "Invalid credentials"}), 401

    token = generate_jwt(user['id'])

    return jsonify({
        "success": True,
        "token": token,
        "user": {
            "id": user['id'],
            "email": user['email'],
            "created_at": user['created_at']
        }
    })

@app.route('/auth/logout', methods=['POST'])
def logout():
    """User logout endpoint"""
    return jsonify({"success": True, "message": "Logged out successfully"})

@app.route('/auth/verify', methods=['GET'])
def verify_token():
    """Verify JWT token"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "No token provided"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    return jsonify({"success": True, "user_id": user_id})

# Character Management Endpoints
@app.route('/characters', methods=['GET'])
def get_characters():
    """Get user's characters"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    user_characters = characters.get(user_id, [])
    return jsonify({
        "success": True,
        "characters": user_characters
    })

@app.route('/characters', methods=['POST'])
def create_character():
    """Create new character"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    data = request.get_json()

    # Validate required fields
    required_fields = ['name', 'strength', 'dexterity', 'agility', 'endurance', 'accuracy']
    for field in required_fields:
        if field not in data:
            return jsonify({"success": False, "error": f"Missing field: {field}"}), 400

    # Create character
    character_id = str(uuid.uuid4())
    character = {
        "id": character_id,
        "name": data['name'],
        "strength": int(data['strength']),
        "dexterity": int(data['dexterity']),
        "agility": int(data['agility']),
        "endurance": int(data['endurance']),
        "accuracy": int(data['accuracy']),
        "level": 1,
        "experience": 0,
        "health": 100,
        "created_at": datetime.utcnow().isoformat(),
        "storage_type": "server",
        "synced": True
    }

    # Store character
    if user_id not in characters:
        characters[user_id] = []
    characters[user_id].append(character)

    # Initialize empty inventory
    inventories[character_id] = {
        "character_id": character_id,
        "items": [],
        "equipment": {},
        "capacity_slots": 12,
        "carry_weight_max": 25.0,
        "last_modified": time.time()
    }

    return jsonify({
        "success": True,
        "character": character
    })

@app.route('/characters/<character_id>', methods=['DELETE'])
def delete_character(character_id):
    """Delete character"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    user_characters = characters.get(user_id, [])
    characters[user_id] = [c for c in user_characters if c['id'] != character_id]

    # Clean up inventory
    if character_id in inventories:
        del inventories[character_id]

    return jsonify({"success": True, "message": "Character deleted"})

# Inventory Endpoints
@app.route('/inventory/<character_id>', methods=['GET'])
def get_inventory(character_id):
    """Get character inventory"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    inventory = inventories.get(character_id, {
        "character_id": character_id,
        "items": [],
        "equipment": {},
        "capacity_slots": 12,
        "carry_weight_max": 25.0,
        "last_modified": time.time()
    })

    return jsonify({
        "success": True,
        "inventory": inventory
    })

@app.route('/inventory/save', methods=['POST'])
def save_inventory():
    """Save character inventory"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    data = request.get_json()
    character_id = data.get('character_id')

    if not character_id:
        return jsonify({"success": False, "error": "character_id required"}), 400

    # Store inventory data
    inventories[character_id] = {
        "character_id": character_id,
        "items": data.get('items', []),
        "equipment": data.get('equipment', {}),
        "capacity_slots": data.get('capacity_slots', 12),
        "carry_weight_max": data.get('carry_weight_max', 25.0),
        "last_modified": time.time()
    }

    return jsonify({"success": True, "message": "Inventory saved"})

# Market Endpoints
@app.route('/market/prices', methods=['GET'])
def get_market_prices():
    """Get current market prices"""
    settlement_id = request.args.get('settlement_id', 1)

    return jsonify({
        "success": True,
        "settlement_id": settlement_id,
        "prices": market_data["prices"],
        "stock": market_data["stock"],
        "timestamp": time.time()
    })

@app.route('/market/events', methods=['POST'])
def market_event():
    """Process market event"""
    token = get_auth_header()
    if not token:
        return jsonify({"success": False, "error": "Authentication required"}), 401

    user_id = verify_jwt(token)
    if not user_id:
        return jsonify({"success": False, "error": "Invalid token"}), 401

    data = request.get_json()

    # Store event
    event = {
        "id": str(uuid.uuid4()),
        "event_type": data.get('event_type', ''),
        "settlement_id": data.get('settlement_id', 1),
        "price_changes": data.get('price_changes', {}),
        "timestamp": data.get('timestamp', time.time()),
        "user_id": user_id
    }

    market_data["events"].append(event)

    # Apply price changes (simple mock logic)
    price_changes = data.get('price_changes', {})
    for item_id, change_data in price_changes.items():
        if item_id in market_data["prices"]:
            new_price = change_data.get('new', market_data["prices"][item_id])
            market_data["prices"][item_id] = max(1, new_price)  # Ensure minimum price

    return jsonify({"success": True, "event_id": event["id"]})

@app.errorhandler(404)
def not_found(error):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"success": False, "error": "Internal server error"}), 500

if __name__ == '__main__':
    print("🚀 Starting Mock API Server for Godot Game Testing")
    print("=" * 50)
    print("📍 Server: http://localhost:8000")
    print("🔧 Mode: Development (In-Memory Storage)")
    print("🎮 For: Milestone Submission Testing")
    print("=" * 50)
    print("📚 Available Endpoints:")
    print("  POST /auth/login        - User login")
    print("  GET  /characters        - List characters")
    print("  POST /characters        - Create character")
    print("  GET  /inventory/<id>    - Get inventory")
    print("  POST /inventory/save    - Save inventory")
    print("  GET  /market/prices     - Market prices")
    print("  POST /market/events     - Market events")
    print("=" * 50)
    print("🧪 Test Login: test@example.com / password123")
    print("🛑 Press Ctrl+C to stop")
    print()

    app.run(host='0.0.0.0', port=8000, debug=True)