//
//  MCPTypes.swift
//  Demo LLM
//
//  Standard Model Context Protocol (MCP) data structures and JSON-RPC 2.0 primitives.
//

import Foundation

// MARK: - JSON-RPC 2.0 Base Types

public struct JSONRPCRequest<T: Encodable>: Encodable {
    public let jsonrpc: String = "2.0"
    public let id: String
    public let method: String
    public let params: T?

    public init(id: String = UUID().uuidString, method: String, params: T? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCResponse<T: Codable>: Codable {
    public let jsonrpc: String
    public let id: String?
    public let result: T?
    public let error: JSONRPCError?

    public init(jsonrpc: String = "2.0", id: String?, result: T? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct JSONRPCError: Codable, Error, LocalizedError {
    public let code: Int
    public let message: String
    public let data: String?

    public init(code: Int, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public var errorDescription: String? {
        "[\(code)] \(message)" + (data != nil ? " (\(data!))" : "")
    }
}

// MARK: - MCP Initialization

public struct MCPInitializeParams: Codable {
    public let protocolVersion: String
    public let clientInfo: MCPClientInfo
    public let capabilities: MCPClientCapabilities

    public init(
        protocolVersion: String = "2024-11-05",
        clientInfo: MCPClientInfo = MCPClientInfo(name: "DemoLLM-MCPHost", version: "1.0.0"),
        capabilities: MCPClientCapabilities = MCPClientCapabilities()
    ) {
        self.protocolVersion = protocolVersion
        self.clientInfo = clientInfo
        self.capabilities = capabilities
    }
}

public struct MCPClientInfo: Codable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct MCPClientCapabilities: Codable {
    public let roots: [String: Bool]?
    public let sampling: [String: Bool]?

    public init(roots: [String: Bool]? = ["listChanged": true], sampling: [String: Bool]? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

public struct MCPInitializeResult: Codable {
    public let protocolVersion: String
    public let serverInfo: MCPServerInfo
    public let capabilities: MCPServerCapabilities

    public init(protocolVersion: String, serverInfo: MCPServerInfo, capabilities: MCPServerCapabilities) {
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.capabilities = capabilities
    }
}

public struct MCPServerInfo: Codable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct MCPServerCapabilities: Codable {
    public let resources: [String: Bool]?
    public let tools: [String: Bool]?
    public let prompts: [String: Bool]?
    public let logging: [String: Bool]?

    public init(
        resources: [String: Bool]? = ["subscribe": false, "listChanged": true],
        tools: [String: Bool]? = ["listChanged": true],
        prompts: [String: Bool]? = ["listChanged": true],
        logging: [String: Bool]? = nil
    ) {
        self.resources = resources
        self.tools = tools
        self.prompts = prompts
        self.logging = logging
    }
}

// MARK: - Context Providers (MCP Resources)

public struct MCPResource: Identifiable, Codable, Equatable {
    public var id: String { uri }
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?

    public init(uri: String, name: String, description: String? = nil, mimeType: String? = "text/plain") {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

public struct MCPListResourcesResult: Codable {
    public let resources: [MCPResource]

    public init(resources: [MCPResource]) {
        self.resources = resources
    }
}

public struct MCPReadResourceParams: Codable {
    public let uri: String

    public init(uri: String) {
        self.uri = uri
    }
}

public struct MCPResourceContent: Codable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: String?

    public init(uri: String, mimeType: String? = "text/plain", text: String? = nil, blob: String? = nil) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
    }
}

public struct MCPReadResourceResult: Codable {
    public let contents: [MCPResourceContent]

    public init(contents: [MCPResourceContent]) {
        self.contents = contents
    }
}

// MARK: - External Tools (MCP Tools)

public struct MCPToolProperty: Codable, Equatable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?

    public init(type: String, description: String? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }
}

public struct MCPToolInputSchema: Codable, Equatable {
    public let type: String
    public let properties: [String: MCPToolProperty]
    public let required: [String]

    public init(type: String = "object", properties: [String: MCPToolProperty], required: [String] = []) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct MCPTool: Identifiable, Codable, Equatable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let inputSchema: MCPToolInputSchema

    public init(name: String, description: String, inputSchema: MCPToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct MCPListToolsResult: Codable {
    public let tools: [MCPTool]

    public init(tools: [MCPTool]) {
        self.tools = tools
    }
}

public struct MCPCallToolParams: Codable {
    public let name: String
    public let arguments: [String: String]

    public init(name: String, arguments: [String: String]) {
        self.name = name
        self.arguments = arguments
    }
}

public struct MCPContentItem: Codable {
    public let type: String
    public let text: String?

    public init(type: String = "text", text: String?) {
        self.type = type
        self.text = text
    }
}

public struct MCPCallToolResult: Codable {
    public let content: [MCPContentItem]
    public let isError: Bool

    public init(content: [MCPContentItem], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

// MARK: - Wire Inspector Item

public enum MCPWireDirection: String, Codable {
    case outgoing = "Host -> Server"
    case incoming = "Server -> Host"
}

public struct MCPWireMessage: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let timestamp: Date = Date()
    public let direction: MCPWireDirection
    public let method: String
    public let rawJSON: String

    public init(direction: MCPWireDirection, method: String, rawJSON: String) {
        self.direction = direction
        self.method = method
        self.rawJSON = rawJSON
    }
}
