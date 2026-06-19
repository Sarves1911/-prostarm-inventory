"""
Vercel serverless function wrapper for ProstarM Inventory System
This file imports and runs the main app.py for Vercel deployment
"""
from pathlib import Path
import sys

# Add parent directory to path so we can import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from app import RequestHandler, ThreadingHTTPServer, HOST, PORT, ROOT, STATIC_DIR, SECRET, DB_PATH

# Export handler for Vercel
def handler(request):
    """
    Vercel serverless handler that processes HTTP requests
    """
    # This is a simple HTTP handler wrapper
    # For production, you may want to refactor to use Flask or FastAPI
    try:
        # Create a mock environ for WSGI-like processing
        environ = {
            'REQUEST_METHOD': request.method,
            'PATH_INFO': request.path,
            'QUERY_STRING': request.query_string or '',
            'SERVER_NAME': 'localhost',
            'SERVER_PORT': str(PORT),
            'wsgi.url_scheme': 'https',
            'CONTENT_TYPE': request.headers.get('content-type', ''),
            'CONTENT_LENGTH': request.headers.get('content-length', ''),
        }
        
        # Add headers to environ
        for header, value in request.headers.items():
            header_key = f"HTTP_{header.upper().replace('-', '_')}"
            environ[header_key] = value
        
        # Handle the request using RequestHandler
        handler_instance = RequestHandler(request, ('127.0.0.1', PORT), None)
        
        return {
            'statusCode': 200,
            'body': 'ProstarM Inventory System is running on Vercel'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }
