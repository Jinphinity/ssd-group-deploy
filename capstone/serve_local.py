#!/usr/bin/env python3
"""
Simple HTTP server for testing Godot WebGL builds locally
Includes CORS headers and proper MIME types for Godot files
"""

import http.server
import socketserver
import os
import sys
from urllib.parse import urlparse

class GodotHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom HTTP handler with CORS and Godot-specific MIME types"""

    def __init__(self, *args, **kwargs):
        # Add Godot-specific MIME types
        self.extensions_map.update({
            '.wasm': 'application/wasm',
            '.pck': 'application/octet-stream',
            '.gdextension': 'application/octet-stream',
        })
        super().__init__(*args, **kwargs)

    def end_headers(self):
        """Add CORS headers to all responses"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        super().end_headers()

    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        """Custom log message format"""
        print(f"[{self.address_string()}] {format % args}")

def serve_directory(directory="./capstone/build/web", port=8080):
    """Serve the specified directory on the given port"""

    if not os.path.exists(directory):
        print(f"❌ Directory not found: {directory}")
        print("💡 Please build the WebGL export first:")
        print("   1. Open Godot project")
        print("   2. Go to Project > Export")
        print("   3. Select 'Web (Production)' preset")
        print("   4. Click 'Export Project'")
        return False

    # Change to the build directory
    os.chdir(directory)

    # Check for required files
    required_files = ['index.html']
    missing_files = [f for f in required_files if not os.path.exists(f)]

    if missing_files:
        print(f"❌ Missing required files: {missing_files}")
        print("💡 Please ensure WebGL export completed successfully")
        return False

    try:
        with socketserver.TCPServer(("", port), GodotHTTPRequestHandler) as httpd:
            print(f"🚀 Serving Godot WebGL build at http://localhost:{port}")
            print(f"📁 Directory: {os.getcwd()}")
            print(f"🌐 Open in browser: http://localhost:{port}")
            print(f"⚠️  Make sure your API server is running on http://localhost:8000")
            print("🛑 Press Ctrl+C to stop")

            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Server stopped")
        return True
    except OSError as e:
        print(f"❌ Failed to start server: {e}")
        if "Address already in use" in str(e):
            print(f"💡 Port {port} is already in use. Try a different port:")
            print(f"   python3 serve_local.py --port 8081")
        return False

def main():
    """Main function with command line argument handling"""
    import argparse

    parser = argparse.ArgumentParser(description='Serve Godot WebGL build locally')
    parser.add_argument('--directory', '-d',
                       default='./capstone/build/web',
                       help='Directory to serve (default: ./capstone/build/web)')
    parser.add_argument('--port', '-p',
                       type=int, default=8080,
                       help='Port to serve on (default: 8080)')

    args = parser.parse_args()

    print("🎮 Godot WebGL Local Server")
    print("=" * 40)

    success = serve_directory(args.directory, args.port)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()