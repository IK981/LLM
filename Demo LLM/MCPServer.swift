//
//  MCPServer.swift
//  Demo LLM
//
//  Embedded Swift MCP Server implementation supporting:
//  - Context Providers (Resources)
//  - External Tools (Tool invocation)
//  - JSON-RPC 2.0 protocol dispatching
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class EmbeddedMCPServer {
    public static let shared = EmbeddedMCPServer()

    // In-memory data store for the context provider & tools
    private var customerCreditBalances: [String: Double] = [
        "alex_smith": 25.00,
        "maria_chen": 80.00
    ]

    private var dispatchLog: [String] = []

    public init() {}

    // MARK: - Server Metadata & Capabilities

    public var serverInfo: MCPServerInfo {
        MCPServerInfo(name: "Swift-Native-Embedded-MCPServer", version: "1.0.0")
    }

    public var capabilities: MCPServerCapabilities {
        MCPServerCapabilities(
            resources: ["subscribe": false, "listChanged": true],
            tools: ["listChanged": true],
            prompts: ["listChanged": false],
            logging: nil
        )
    }

    // MARK: - 1. Context Providers (Resources)

    public func listResources() -> [MCPResource] {
        [
            MCPResource(
                uri: "device://system_metrics",
                name: "Device Hardware & OS Metrics",
                description: "Live on-device metrics including battery level, thermal state, memory, and OS info.",
                mimeType: "application/json"
            ),
            MCPResource(
                uri: "customer://profile/alex_smith",
                name: "Customer Profile: Alex Smith",
                description: "CRM context for user Alex Smith (VIP tier, past orders, active tickets).",
                mimeType: "text/plain"
            ),
            MCPResource(
                uri: "kb://company_refund_policy",
                name: "Store Credit & Refund Knowledge Base",
                description: "Official policy guidelines, threshold limits, and SLA rules for customer recovery.",
                mimeType: "text/markdown"
            )
        ]
    }

    public func readResource(uri: String) throws -> MCPResourceContent {
        switch uri {
        case "device://system_metrics":
            let json = getDeviceMetricsJSON()
            return MCPResourceContent(uri: uri, mimeType: "application/json", text: json)

        case "customer://profile/alex_smith":
            let balance = customerCreditBalances["alex_smith"] ?? 0.0
            let profile = """
            [CUSTOMER CRM RECORD]
            ID: cust_alex_smith
            Name: Alex Smith
            Tier: Platinum Elite
            Current Store Credit: $\(String(format: "%.2f", balance))
            Recent Orders:
              • ORD-9021 (Delayed in Transit: 3 days overdue)
              • ORD-8102 (Delivered: 5-Star Review)
            Active Support Note: Customer reported frustration regarding delay of ORD-9021.
            """
            return MCPResourceContent(uri: uri, mimeType: "text/plain", text: profile)

        case "kb://company_refund_policy":
            let policy = """
            # Customer Recovery Policy (Rev 2026.1)
            1. **Shipping Delays (>48 hrs)**: Automatic qualification for $10 - $25 store credit.
            2. **Elite / Platinum Tier**: Instant compensation limit up to $50 without escalation.
            3. **Notification**: After granting store credit, an automated recovery dispatch must be sent to the operations channel.
            """
            return MCPResourceContent(uri: uri, mimeType: "text/markdown", text: policy)

        default:
            throw JSONRPCError(code: -32602, message: "Resource not found for URI: \(uri)")
        }
    }

    // MARK: - 2. External Tools

    public func listTools() -> [MCPTool] {
        [
            MCPTool(
                name: "issue_store_credit",
                description: "Applies store credit to a customer's account as compensation or promotional reward.",
                inputSchema: MCPToolInputSchema(
                    properties: [
                        "customer_id": MCPToolProperty(type: "string", description: "Customer account identifier (e.g. alex_smith)"),
                        "amount": MCPToolProperty(type: "string", description: "Credit amount in USD (e.g. 20.00)"),
                        "reason": MCPToolProperty(type: "string", description: "Audit justification for issuing credit")
                    ],
                    required: ["customer_id", "amount", "reason"]
                )
            ),
            MCPTool(
                name: "lookup_device_status",
                description: "Queries the local device hardware to inspect battery, storage, and thermal state.",
                inputSchema: MCPToolInputSchema(
                    properties: [
                        "include_thermal": MCPToolProperty(type: "string", description: "Pass 'true' or 'false' to include thermal sensors", enumValues: ["true", "false"])
                    ],
                    required: []
                )
            ),
            MCPTool(
                name: "calculate_discounted_price",
                description: "Calculates the final cart total given an original subtotal and promotional coupon code.",
                inputSchema: MCPToolInputSchema(
                    properties: [
                        "subtotal": MCPToolProperty(type: "string", description: "Original order amount (e.g. 150.00)"),
                        "promo_code": MCPToolProperty(type: "string", description: "Discount code (e.g. VIP20, WELCOME10, SAVE50)")
                    ],
                    required: ["subtotal", "promo_code"]
                )
            ),
            MCPTool(
                name: "dispatch_support_alert",
                description: "Dispatches a high-priority operational alert to the support team or Slack bridge.",
                inputSchema: MCPToolInputSchema(
                    properties: [
                        "channel": MCPToolProperty(type: "string", description: "Target channel (e.g. #customer-ops, #urgent-escalations)"),
                        "message": MCPToolProperty(type: "string", description: "Notification payload"),
                        "priority": MCPToolProperty(type: "string", description: "Priority level", enumValues: ["NORMAL", "URGENT", "CRITICAL"])
                    ],
                    required: ["channel", "message", "priority"]
                )
            )
        ]
    }

    public func callTool(name: String, arguments: [String: String]) throws -> MCPCallToolResult {
        switch name {
        case "issue_store_credit":
            guard let customerId = arguments["customer_id"], !customerId.isEmpty else {
                throw JSONRPCError(code: -32602, message: "Missing required argument 'customer_id'")
            }
            guard let amountStr = arguments["amount"], let amount = Double(amountStr), amount > 0 else {
                throw JSONRPCError(code: -32602, message: "Invalid argument 'amount': must be a positive number")
            }
            let reason = arguments["reason"] ?? "General customer satisfaction"

            let current = customerCreditBalances[customerId] ?? 0.0
            let newBalance = current + amount
            customerCreditBalances[customerId] = newBalance

            let summary = """
            [MCP TOOL EXECUTION: issue_store_credit]
            • Status: SUCCESS
            • Account: \(customerId)
            • Amount Added: $\(String(format: "%.2f", amount))
            • Previous Balance: $\(String(format: "%.2f", current))
            • Updated Balance: $\(String(format: "%.2f", newBalance))
            • Audit Note: "\(reason)"
            • Transaction ID: TXN-MCP-\(Int.random(in: 100000...999999))
            """
            return MCPCallToolResult(content: [MCPContentItem(type: "text", text: summary)], isError: false)

        case "lookup_device_status":
            let json = getDeviceMetricsJSON()
            return MCPCallToolResult(content: [MCPContentItem(type: "text", text: json)], isError: false)

        case "calculate_discounted_price":
            let subtotal = Double(arguments["subtotal"] ?? "0") ?? 0.0
            let code = (arguments["promo_code"] ?? "").uppercased()

            var discountPercent: Double = 0.0
            switch code {
            case "VIP20": discountPercent = 0.20
            case "WELCOME10": discountPercent = 0.10
            case "SAVE50": discountPercent = 0.50
            default: discountPercent = 0.05
            }

            let savings = subtotal * discountPercent
            let finalPrice = max(0.0, subtotal - savings)

            let result = """
            [MCP TOOL EXECUTION: calculate_discounted_price]
            • Original Subtotal: $\(String(format: "%.2f", subtotal))
            • Applied Promo: \(code.isEmpty ? "NONE" : code) (\(Int(discountPercent * 100))% off)
            • Savings: $\(String(format: "%.2f", savings))
            • Final Amount Due: $\(String(format: "%.2f", finalPrice))
            """
            return MCPCallToolResult(content: [MCPContentItem(type: "text", text: result)], isError: false)

        case "dispatch_support_alert":
            let channel = arguments["channel"] ?? "#general"
            let message = arguments["message"] ?? "Alert triggered"
            let priority = arguments["priority"] ?? "NORMAL"

            let logEntry = "[\(priority)] \(channel): \(message)"
            dispatchLog.append(logEntry)

            let result = """
            [MCP TOOL EXECUTION: dispatch_support_alert]
            • Target: \(channel)
            • Priority: \(priority)
            • Payload: "\(message)"
            • Delivery Status: SENT via Simulated Webhook (Queue Size: \(dispatchLog.count))
            """
            return MCPCallToolResult(content: [MCPContentItem(type: "text", text: result)], isError: false)

        default:
            throw JSONRPCError(code: -32601, message: "Method / tool not found: \(name)")
        }
    }

    // MARK: - JSON-RPC 2.0 Dispatcher

    public func handleJSONRPC(requestData: Data) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonObject = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any],
              let method = jsonObject["method"] as? String else {
            let errResponse = JSONRPCResponse<String>(id: nil, error: JSONRPCError(code: -32700, message: "Parse error"))
            return (try? encoder.encode(errResponse)) ?? Data()
        }

        let requestId = jsonObject["id"] as? String ?? "0"

        do {
            switch method {
            case "initialize":
                let initResult = MCPInitializeResult(
                    protocolVersion: "2024-11-05",
                    serverInfo: serverInfo,
                    capabilities: capabilities
                )
                let resp = JSONRPCResponse(id: requestId, result: initResult)
                return try encoder.encode(resp)

            case "resources/list":
                let resources = listResources()
                let resp = JSONRPCResponse(id: requestId, result: MCPListResourcesResult(resources: resources))
                return try encoder.encode(resp)

            case "resources/read":
                guard let params = jsonObject["params"] as? [String: Any],
                      let uri = params["uri"] as? String else {
                    throw JSONRPCError(code: -32602, message: "Missing 'uri' parameter in resources/read")
                }
                let content = try readResource(uri: uri)
                let resp = JSONRPCResponse(id: requestId, result: MCPReadResourceResult(contents: [content]))
                return try encoder.encode(resp)

            case "tools/list":
                let tools = listTools()
                let resp = JSONRPCResponse(id: requestId, result: MCPListToolsResult(tools: tools))
                return try encoder.encode(resp)

            case "tools/call":
                guard let params = jsonObject["params"] as? [String: Any],
                      let toolName = params["name"] as? String else {
                    throw JSONRPCError(code: -32602, message: "Missing 'name' parameter in tools/call")
                }
                var stringArgs: [String: String] = [:]
                if let rawArgs = params["arguments"] as? [String: Any] {
                    for (k, v) in rawArgs {
                        stringArgs[k] = "\(v)"
                    }
                }
                let callResult = try callTool(name: toolName, arguments: stringArgs)
                let resp = JSONRPCResponse(id: requestId, result: callResult)
                return try encoder.encode(resp)

            case "ping":
                let resp = JSONRPCResponse(id: requestId, result: ["status": "pong"])
                return try encoder.encode(resp)

            default:
                throw JSONRPCError(code: -32601, message: "Method not supported: \(method)")
            }
        } catch let rpcErr as JSONRPCError {
            let resp = JSONRPCResponse<String>(id: requestId, error: rpcErr)
            return (try? encoder.encode(resp)) ?? Data()
        } catch {
            let resp = JSONRPCResponse<String>(id: requestId, error: JSONRPCError(code: -32603, message: error.localizedDescription))
            return (try? encoder.encode(resp)) ?? Data()
        }
    }

    // MARK: - Hardware Helper

    private func getDeviceMetricsJSON() -> String {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel >= 0 ? "\(Int(UIDevice.current.batteryLevel * 100))%" : "Simulator (100%)"
        let batteryState: String
        switch UIDevice.current.batteryState {
        case .charging: batteryState = "Charging"
        case .full: batteryState = "Full"
        case .unplugged: batteryState = "Unplugged"
        default: batteryState = "AC Powered"
        }
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        #else
        let batteryLevel = "100% (AC)"
        let batteryState = "AC Powered"
        let systemName = "macOS"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let model = "Mac"
        #endif

        let thermalState: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "Nominal (Cool)"
        case .fair: thermalState = "Fair"
        case .serious: thermalState = "Serious (Throttling)"
        case .critical: thermalState = "Critical"
        @unknown default: thermalState = "Nominal"
        }

        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = String(format: "%.1f GB", Double(memoryBytes) / 1_073_741_824.0)

        return """
        {
          "device": "\(model)",
          "os": "\(systemName) \(systemVersion)",
          "battery": {
            "level": "\(batteryLevel)",
            "state": "\(batteryState)"
          },
          "thermal_state": "\(thermalState)",
          "physical_memory": "\(memoryGB)",
          "active_processors": \(ProcessInfo.processInfo.activeProcessorCount)
        }
        """
    }
}
