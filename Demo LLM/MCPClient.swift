//
//  MCPClient.swift
//  Demo LLM
//
//  Model Context Protocol (MCP) Client and Agent Coordinator.
//  Bridges LLM queries with Context Providers (Resources) and External Tools (Tools).
//

import Foundation
import Combine

public protocol MCPClientProtocol: AnyObject {
    var isConnected: Bool { get }
    var wireLogs: [MCPWireMessage] { get }
    func initialize() async throws -> MCPInitializeResult
    func listResources() async throws -> [MCPResource]
    func readResource(uri: String) async throws -> MCPResourceContent
    func listTools() async throws -> [MCPTool]
    func callTool(name: String, arguments: [String: String]) async throws -> MCPCallToolResult
    func clearLogs()
}

// MARK: - In-Memory Embedded Client

public final class EmbeddedMCPClient: ObservableObject, MCPClientProtocol {
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var wireLogs: [MCPWireMessage] = []

    private let server = EmbeddedMCPServer.shared
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    public init() {}

    public func clearLogs() {
        wireLogs.removeAll()
    }

    private func logOutgoing(method: String, payload: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.wireLogs.insert(MCPWireMessage(direction: .outgoing, method: method, rawJSON: str), at: 0)
            }
        }
    }

    private func logIncoming(method: String, responseData: Data) {
        if let json = try? JSONSerialization.jsonObject(with: responseData),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: prettyData, encoding: .utf8) {
            DispatchQueue.main.async {
                self.wireLogs.insert(MCPWireMessage(direction: .incoming, method: method, rawJSON: str), at: 0)
            }
        }
    }

    private func sendRPC(method: String, params: [String: Any]) throws -> [String: Any] {
        let reqId = UUID().uuidString.prefix(8)
        let requestDict: [String: Any] = [
            "jsonrpc": "2.0",
            "id": String(reqId),
            "method": method,
            "params": params
        ]

        logOutgoing(method: method, payload: requestDict)

        let reqData = try JSONSerialization.data(withJSONObject: requestDict)
        let respData = server.handleJSONRPC(requestData: reqData)

        logIncoming(method: method, responseData: respData)

        guard let respDict = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
            throw JSONRPCError(code: -32700, message: "Invalid JSON-RPC response from server")
        }

        if let errorDict = respDict["error"] as? [String: Any],
           let msg = errorDict["message"] as? String,
           let code = errorDict["code"] as? Int {
            throw JSONRPCError(code: code, message: msg)
        }

        guard let result = respDict["result"] as? [String: Any] else {
            throw JSONRPCError(code: -32603, message: "Response missing 'result' field")
        }

        return result
    }

    // MARK: - Protocol Methods

    public func initialize() async throws -> MCPInitializeResult {
        let params: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "clientInfo": ["name": "DemoLLM-SwiftHost", "version": "1.0.0"],
            "capabilities": ["roots": ["listChanged": true]]
        ]

        let result = try sendRPC(method: "initialize", params: params)
        let data = try JSONSerialization.data(withJSONObject: result)
        let initResult = try JSONDecoder().decode(MCPInitializeResult.self, from: data)

        await MainActor.run {
            self.isConnected = true
        }
        return initResult
    }

    public func listResources() async throws -> [MCPResource] {
        let result = try sendRPC(method: "resources/list", params: [:])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPListResourcesResult.self, from: data)
        return decoded.resources
    }

    public func readResource(uri: String) async throws -> MCPResourceContent {
        let result = try sendRPC(method: "resources/read", params: ["uri": uri])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPReadResourceResult.self, from: data)
        guard let first = decoded.contents.first else {
            throw JSONRPCError(code: -32603, message: "Empty resource content")
        }
        return first
    }

    public func listTools() async throws -> [MCPTool] {
        let result = try sendRPC(method: "tools/list", params: [:])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPListToolsResult.self, from: data)
        return decoded.tools
    }

    public func callTool(name: String, arguments: [String: String]) async throws -> MCPCallToolResult {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        let result = try sendRPC(method: "tools/call", params: params)
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPCallToolResult.self, from: data)
        return decoded
    }
}

// MARK: - Remote HTTP / SSE Client (For External Python/Node Server)

public final class RemoteHTTPMCPClient: ObservableObject, MCPClientProtocol {
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var wireLogs: [MCPWireMessage] = []

    public var serverEndpoint: String = "http://localhost:8000/mcp"

    public init() {}

    public func clearLogs() {
        wireLogs.removeAll()
    }

    private func sendRPC(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: serverEndpoint) else {
            throw JSONRPCError(code: -32600, message: "Invalid endpoint URL: \(serverEndpoint)")
        }

        let reqId = UUID().uuidString.prefix(8)
        let requestDict: [String: Any] = [
            "jsonrpc": "2.0",
            "id": String(reqId),
            "method": method,
            "params": params
        ]

        let reqData = try JSONSerialization.data(withJSONObject: requestDict, options: [.prettyPrinted, .sortedKeys])
        let reqString = String(data: reqData, encoding: .utf8) ?? "{}"

        await MainActor.run {
            self.wireLogs.insert(MCPWireMessage(direction: .outgoing, method: method, rawJSON: reqString), at: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = reqData
        request.timeoutInterval = 5.0

        let (data, response) = try await URLSession.shared.data(for: request)

        let respString = String(data: data, encoding: .utf8) ?? "{}"
        await MainActor.run {
            self.wireLogs.insert(MCPWireMessage(direction: .incoming, method: method, rawJSON: respString), at: 0)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw JSONRPCError(code: -32603, message: "HTTP Server returned status \((response as? HTTPURLResponse)?.statusCode ?? 500)")
        }

        guard let respDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JSONRPCError(code: -32700, message: "Malformed JSON response from remote server")
        }

        if let errorDict = respDict["error"] as? [String: Any],
           let msg = errorDict["message"] as? String,
           let code = errorDict["code"] as? Int {
            throw JSONRPCError(code: code, message: msg)
        }

        guard let result = respDict["result"] as? [String: Any] else {
            throw JSONRPCError(code: -32603, message: "Response missing 'result'")
        }

        return result
    }

    public func initialize() async throws -> MCPInitializeResult {
        let params: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "clientInfo": ["name": "DemoLLM-RemoteClient", "version": "1.0.0"],
            "capabilities": [:]
        ]
        let result = try await sendRPC(method: "initialize", params: params)
        let data = try JSONSerialization.data(withJSONObject: result)
        let initResult = try JSONDecoder().decode(MCPInitializeResult.self, from: data)
        await MainActor.run { self.isConnected = true }
        return initResult
    }

    public func listResources() async throws -> [MCPResource] {
        let result = try await sendRPC(method: "resources/list", params: [:])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPListResourcesResult.self, from: data)
        return decoded.resources
    }

    public func readResource(uri: String) async throws -> MCPResourceContent {
        let result = try await sendRPC(method: "resources/read", params: ["uri": uri])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPReadResourceResult.self, from: data)
        guard let first = decoded.contents.first else {
            throw JSONRPCError(code: -32603, message: "Empty resource content")
        }
        return first
    }

    public func listTools() async throws -> [MCPTool] {
        let result = try await sendRPC(method: "tools/list", params: [:])
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPListToolsResult.self, from: data)
        return decoded.tools
    }

    public func callTool(name: String, arguments: [String: String]) async throws -> MCPCallToolResult {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        let result = try await sendRPC(method: "tools/call", params: params)
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoded = try JSONDecoder().decode(MCPCallToolResult.self, from: data)
        return decoded
    }
}
