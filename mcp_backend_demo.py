#!/usr/bin/env python3
"""
Lightweight standalone MCP HTTP Server (Zero extra external dependencies required)
Runs an MCP-compliant JSON-RPC 2.0 server at http://localhost:8000/mcp

Usage:
    python3 mcp_backend_demo.py
"""

import json
from http.server import HTTPServer, BaseHTTPRequestHandler

CUSTOMER_DB = {
    "alex_smith": {
        "name": "Alex Smith",
        "tier": "Platinum Elite (Remote Backend)",
        "credit_balance": 45.00,
        "recent_orders": ["ORD-9021 (Delayed)", "ORD-8102 (Delivered)"]
    }
}

class MCPHTTPRequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        # Health check
        self._set_headers(200)
        self.wfile.write(json.dumps({"status": "MCP Server Running", "protocol": "2024-11-05"}).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            req = json.loads(post_data.decode('utf-8'))
            req_id = req.get("id", "0")
            method = req.get("method")
            params = req.get("params", {})

            result = None
            error = None

            if method == "initialize":
                result = {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {
                        "name": "Python-Remote-MCPServer",
                        "version": "1.0.0"
                    },
                    "capabilities": {
                        "resources": {"listChanged": True},
                        "tools": {"listChanged": True}
                    }
                }
            elif method == "resources/list":
                result = {
                    "resources": [
                        {
                            "uri": "customer://profile/alex_smith",
                            "name": "Remote CRM Customer Profile",
                            "description": "Live CRM data from Python backend",
                            "mimeType": "text/plain"
                        }
                    ]
                }
            elif method == "resources/read":
                uri = params.get("uri")
                if uri == "customer://profile/alex_smith":
                    c = CUSTOMER_DB["alex_smith"]
                    profile_text = f"REMOTE PYTHON CRM:\nName: {c['name']}\nTier: {c['tier']}\nBalance: ${c['credit_balance']:.2f}"
                    result = {
                        "contents": [
                            {"uri": uri, "mimeType": "text/plain", "text": profile_text}
                        ]
                    }
                else:
                    error = {"code": -32602, "message": f"Resource not found: {uri}"}

            elif method == "tools/list":
                result = {
                    "tools": [
                        {
                            "name": "issue_store_credit",
                            "description": "Issue store credit on remote backend",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "customer_id": {"type": "string"},
                                    "amount": {"type": "string"},
                                    "reason": {"type": "string"}
                                },
                                "required": ["customer_id", "amount", "reason"]
                            }
                        }
                    ]
                }
            elif method == "tools/call":
                tool_name = params.get("name")
                args = params.get("arguments", {})
                if tool_name == "issue_store_credit":
                    cust_id = args.get("customer_id", "alex_smith")
                    amount = float(args.get("amount", "20.00"))
                    reason = args.get("reason", "No reason provided")
                    
                    if cust_id in CUSTOMER_DB:
                        CUSTOMER_DB[cust_id]["credit_balance"] += amount
                        new_bal = CUSTOMER_DB[cust_id]["credit_balance"]
                    else:
                        new_bal = amount

                    result = {
                        "content": [
                            {
                                "type": "text",
                                "text": f"[REMOTE PYTHON MCP EXECUTION]\nAccount: {cust_id}\nAdded: ${amount:.2f}\nNew Balance: ${new_bal:.2f}\nAudit: {reason}"
                            }
                        ],
                        "isError": False
                    }
                else:
                    error = {"code": -32601, "message": f"Tool '{tool_name}' not found on remote server"}
            else:
                error = {"code": -32601, "message": f"Method '{method}' not implemented"}

            response_payload = {
                "jsonrpc": "2.0",
                "id": req_id
            }
            if error:
                response_payload["error"] = error
            else:
                response_payload["result"] = result

            self._set_headers(200)
            self.wfile.write(json.dumps(response_payload, indent=2).encode('utf-8'))

        except Exception as e:
            self._set_headers(500)
            err_resp = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)}
            }
            self.wfile.write(json.dumps(err_resp).encode('utf-8'))

def run_server(port=8000):
    server_address = ('', port)
    httpd = HTTPServer(server_address, MCPHTTPRequestHandler)
    print(f"🚀 MCP HTTP Server running on http://localhost:{port}/mcp")
    print("Press Ctrl+C to stop.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()

if __name__ == '__main__':
    run_server(8000)
