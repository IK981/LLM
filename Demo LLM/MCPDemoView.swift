//
//  MCPDemoView.swift
//  Demo LLM
//
//  Complete interactive Model Context Protocol (MCP) Studio View.
//  Demonstrates:
//  1. Agent orchestration with Context Providers & External Tools
//  2. Live Context Provider Explorer (MCP Resources)
//  3. Tool Registry & Manual Tool Invocation (MCP Tools)
//  4. Raw JSON-RPC 2.0 Wire Inspector
//  5. Embedded Swift vs Remote Backend switcher
//

import SwiftUI
import Combine

public enum MCPServerMode: String, CaseIterable, Identifiable {
    case embedded = "Embedded Swift MCP"
    case remoteHttp = "Remote Server (HTTP/SSE)"

    public var id: String { rawValue }
}

public struct MCPAgentStep: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let icon: String
    public let status: StepStatus

    public enum StepStatus {
        case pending, inProgress, completed, failed
    }
}

@MainActor
public final class MCPDemoViewModel: ObservableObject {
    @Published public var serverMode: MCPServerMode = .embedded
    @Published public var remoteEndpoint: String = "http://localhost:8000/mcp"
    @Published public var isConnected: Bool = false
    @Published public var serverDetails: String = "Not connected"
    
    @Published public var resources: [MCPResource] = []
    @Published public var selectedResource: MCPResource?
    @Published public var selectedResourceContent: String = ""
    @Published public var isLoadingResource: Bool = false
    
    @Published public var tools: [MCPTool] = []
    @Published public var selectedTool: MCPTool?
    @Published public var toolArguments: [String: String] = [:]
    @Published public var toolResultText: String = ""
    @Published public var isRunningTool: Bool = false

    @Published public var userPrompt: String = "Alex Smith is frustrated about delayed order ORD-9021. Resolve the situation and issue store credit."
    @Published public var agentSteps: [MCPAgentStep] = []
    @Published public var agentFinalAnswer: String = ""
    @Published public var isAgentThinking: Bool = false

    @Published public var wireMessages: [MCPWireMessage] = []

    private let embeddedClient = EmbeddedMCPClient()
    private let remoteClient = RemoteHTTPMCPClient()

    public init() {
        connectServer()
    }

    public var activeClient: any MCPClientProtocol {
        switch serverMode {
        case .embedded: return embeddedClient
        case .remoteHttp: return remoteClient
        }
    }

    public func connectServer() {
        Task {
            isAgentThinking = true
            do {
                if serverMode == .remoteHttp {
                    remoteClient.serverEndpoint = remoteEndpoint
                }
                
                let initResult = try await activeClient.initialize()
                self.serverDetails = "\(initResult.serverInfo.name) v\(initResult.serverInfo.version) (Protocol \(initResult.protocolVersion))"
                self.isConnected = true

                // Refresh resources & tools
                self.resources = try await activeClient.listResources()
                self.tools = try await activeClient.listTools()

                if let firstRes = resources.first {
                    self.selectResource(firstRes)
                }
                if let firstTool = tools.first {
                    self.selectTool(firstTool)
                }
            } catch {
                self.isConnected = false
                self.serverDetails = "Connection failed: \(error.localizedDescription)"
            }
            refreshWireLogs()
            isAgentThinking = false
        }
    }

    public func selectResource(_ resource: MCPResource) {
        selectedResource = resource
        selectedResourceContent = "Loading resource context..."
        isLoadingResource = true

        Task {
            do {
                let content = try await activeClient.readResource(uri: resource.uri)
                selectedResourceContent = content.text ?? (content.blob ?? "No text content")
            } catch {
                selectedResourceContent = "Error reading resource: \(error.localizedDescription)"
            }
            refreshWireLogs()
            isLoadingResource = false
        }
    }

    public func selectTool(_ tool: MCPTool) {
        selectedTool = tool
        toolResultText = ""
        toolArguments.removeAll()
        for key in tool.inputSchema.properties.keys {
            switch key {
            case "customer_id": toolArguments[key] = "alex_smith"
            case "amount": toolArguments[key] = "20.00"
            case "reason": toolArguments[key] = "Service apology for ORD-9021 delay"
            case "subtotal": toolArguments[key] = "150.00"
            case "promo_code": toolArguments[key] = "VIP20"
            case "channel": toolArguments[key] = "#customer-ops"
            case "message": toolArguments[key] = "Customer Alex Smith granted $20 store credit."
            case "priority": toolArguments[key] = "URGENT"
            case "include_thermal": toolArguments[key] = "true"
            default: toolArguments[key] = ""
            }
        }
    }

    public func executeSelectedTool() {
        guard let tool = selectedTool else { return }
        isRunningTool = true
        toolResultText = "Executing \(tool.name) via MCP 'tools/call'..."

        Task {
            do {
                let result = try await activeClient.callTool(name: tool.name, arguments: toolArguments)
                let text = result.content.compactMap { $0.text }.joined(separator: "\n")
                self.toolResultText = text.isEmpty ? "Execution finished without output." : text
            } catch {
                self.toolResultText = "Tool Call Failed: \(error.localizedDescription)"
            }
            refreshWireLogs()
            isRunningTool = false
        }
    }

    // MARK: - Autonomous MCP Agent Loop Demo

    public func runAgentPipeline() {
        guard !isAgentThinking else { return }
        isAgentThinking = true
        agentSteps.removeAll()
        agentFinalAnswer = ""

        Task {
            // Step 1: Discover Tools & Context
            agentSteps.append(MCPAgentStep(
                title: "1. Query MCP Context Provider (Resource)",
                detail: "Reading 'customer://profile/alex_smith' & 'kb://company_refund_policy'",
                icon: "doc.text.magnifyingglass",
                status: .inProgress
            ))
            try? await Task.sleep(nanoseconds: 600_000_000)

            let customerContext: String
            let policyContext: String
            do {
                let cRes = try await activeClient.readResource(uri: "customer://profile/alex_smith")
                let pRes = try await activeClient.readResource(uri: "kb://company_refund_policy")
                customerContext = cRes.text ?? ""
                policyContext = pRes.text ?? ""
            } catch {
                customerContext = "Unable to fetch customer context."
                policyContext = "Unable to fetch policy."
            }

            agentSteps[0] = MCPAgentStep(
                title: "1. Query MCP Context Provider (Resource)",
                detail: "Context injected into LLM: Platinum Elite status & delay on ORD-9021 confirmed.",
                icon: "doc.text.magnifyingglass",
                status: .completed
            )

            // Step 2: Agent Tool Discovery & Selection
            agentSteps.append(MCPAgentStep(
                title: "2. Discover Tools from MCP Server",
                detail: "Scanning registered tools via 'tools/list'. Target matched: 'issue_store_credit'",
                icon: "wrench.and.screwdriver",
                status: .inProgress
            ))
            try? await Task.sleep(nanoseconds: 500_000_000)

            agentSteps[1] = MCPAgentStep(
                title: "2. Discover Tools from MCP Server",
                detail: "Selected 'issue_store_credit' with arguments { customer_id: 'alex_smith', amount: '25.00' }",
                icon: "wrench.and.screwdriver",
                status: .completed
            )

            // Step 3: Tool Execution over MCP JSON-RPC
            agentSteps.append(MCPAgentStep(
                title: "3. Execute External Action ('tools/call')",
                detail: "Sending JSON-RPC 'tools/call' request to MCP server...",
                icon: "bolt.badge.clock",
                status: .inProgress
            ))
            try? await Task.sleep(nanoseconds: 700_000_000)

            let toolOutput: String
            do {
                let result = try await activeClient.callTool(name: "issue_store_credit", arguments: [
                    "customer_id": "alex_smith",
                    "amount": "25.00",
                    "reason": "Delay on ORD-9021 per Customer Recovery Policy"
                ])
                toolOutput = result.content.compactMap { $0.text }.joined(separator: "\n")
            } catch {
                toolOutput = "Tool call failed: \(error.localizedDescription)"
            }

            agentSteps[2] = MCPAgentStep(
                title: "3. Execute External Action ('tools/call')",
                detail: "Executed successfully: $25.00 applied to Alex Smith's account.",
                icon: "checkmark.circle.fill",
                status: .completed
            )

            // Step 4: Dispatch Notification Tool
            agentSteps.append(MCPAgentStep(
                title: "4. Follow-up Tool: Dispatch Alert",
                detail: "Calling 'dispatch_support_alert' for audit compliance...",
                icon: "bell.badge",
                status: .inProgress
            ))
            try? await Task.sleep(nanoseconds: 500_000_000)

            _ = try? await activeClient.callTool(name: "dispatch_support_alert", arguments: [
                "channel": "#customer-ops",
                "message": "Issued $25 credit to Alex Smith for ORD-9021",
                "priority": "NORMAL"
            ])

            agentSteps[3] = MCPAgentStep(
                title: "4. Follow-up Tool: Dispatch Alert",
                detail: "Alert queued to #customer-ops via MCP tool.",
                icon: "bell.badge.fill",
                status: .completed
            )

            // Step 5: Final LLM Synthesis
            agentSteps.append(MCPAgentStep(
                title: "5. Grounded LLM Synthesis",
                detail: "Synthesizing final response combining context and tool execution proofs.",
                icon: "sparkles",
                status: .completed
            ))

            agentFinalAnswer = """
            ### Resolution Summary for Alex Smith

            **Customer Context Ingested via MCP (`customer://profile/alex_smith`):**
            \(customerContext.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))

            **Policy Verified via MCP (`kb://company_refund_policy`):**
            \(policyContext.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))

            **Actions Executed via MCP Tools:**
            1.  **`issue_store_credit` Output**:
            \(toolOutput.components(separatedBy: "\n").prefix(3).joined(separator: "\n"))
            2.  **`dispatch_support_alert`**: Automated notification logged to `#customer-ops`.

            **Customer Facing Message Generated:**
            > *"Dear Alex, we deeply apologize for the delay on order ORD-9021. As a valued Platinum Elite member, we've automatically credited **$25.00** to your account balance for your next purchase. Our logistics team has been notified to expedite delivery immediately."*
            """

            refreshWireLogs()
            isAgentThinking = false
        }
    }

    public func setScenario(_ index: Int) {
        switch index {
        case 0:
            userPrompt = "Alex Smith is frustrated about delayed order ORD-9021. Resolve the situation and issue store credit."
        case 1:
            userPrompt = "Inspect current device hardware health, battery level, and thermal throttling state."
        case 2:
            userPrompt = "Customer has a $180 cart and promo code VIP20. Compute discounted total and report."
        default:
            userPrompt = "Send a high-priority incident alert to the operations Slack channel."
        }
    }

    public func refreshWireLogs() {
        self.wireMessages = activeClient.wireLogs
    }

    public func clearWireLogs() {
        activeClient.clearLogs()
        wireMessages.removeAll()
    }
}

// MARK: - MCP Studio Main View

public struct MCPDemoView: View {
    @StateObject private var viewModel = MCPDemoViewModel()
    @State private var selectedSection: Int = 0

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Connection Status Bar
                serverStatusBar

                // Segmented Selector
                Picker("Section", selection: $selectedSection) {
                    Text("AI Agent Demo").tag(0)
                    Text("Context (Resources)").tag(1)
                    Text("Tools Registry").tag(2)
                    Text("JSON-RPC Wire").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Main Content
                TabView(selection: $selectedSection) {
                    agentDemoTab.tag(0)
                    resourcesTab.tag(1)
                    toolsTab.tag(2)
                    wireInspectorTab.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("MCP Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Server Transport") {
                            ForEach(MCPServerMode.allCases) { mode in
                                Button {
                                    viewModel.serverMode = mode
                                    viewModel.connectServer()
                                } label: {
                                    HStack {
                                        Text(mode.rawValue)
                                        if viewModel.serverMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Section("Actions") {
                            Button {
                                viewModel.connectServer()
                            } label: {
                                Label("Reconnect / Ping", systemImage: "arrow.clockwise")
                            }

                            Button(role: .destructive) {
                                viewModel.clearWireLogs()
                            } label: {
                                Label("Clear Wire Logs", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                    }
                }
            }
        }
    }

    // MARK: - Server Status Bar

    private var serverStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.serverMode.rawValue)
                        .font(.system(size: 12, weight: .bold))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(viewModel.isConnected ? .green : .red)
                }
                Text(viewModel.serverDetails)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.serverMode == .embedded {
                Text("Zero Backend Req.")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            } else {
                Text("HTTP SSE")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Tab 1: AI Agent Demo

    private var agentDemoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Intro Banner
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundColor(.purple)
                            .font(.system(size: 18, weight: .bold))
                        Text("Autonomous MCP Agent Flow")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("Watch how the AI connects to external context providers (Resources) and takes action with tools (Tools) via the Model Context Protocol.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)

                // Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Demo Scenarios")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            presetButton(" Alex Late Delivery", index: 0)
                            presetButton(" Device Diagnostics", index: 1)
                            presetButton(" Cart VIP Discount", index: 2)
                        }
                    }
                }

                // Prompt Input Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("User Prompt")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    TextEditor(text: $viewModel.userPrompt)
                        .frame(minHeight: 70)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .font(.system(size: 14))

                    Button {
                        viewModel.runAgentPipeline()
                    } label: {
                        HStack {
                            if viewModel.isAgentThinking {
                                ProgressView()
                                    .tint(.white)
                                Text("Agent Running MCP Protocol...")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Execute MCP Agent Pipeline")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.isAgentThinking ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isAgentThinking)
                }

                // Agent Execution Steps
                if !viewModel.agentSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MCP Protocol Execution Trace")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 8) {
                            ForEach(viewModel.agentSteps) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: step.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(step.status == .completed ? .green : .purple)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.title)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(step.detail)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if step.status == .inProgress {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                }

                // Final Answer
                if !viewModel.agentFinalAnswer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Augmented AI Output")
                                .font(.system(size: 14, weight: .bold))
                        }

                        Text(LocalizedStringKey(viewModel.agentFinalAnswer))
                            .font(.system(size: 13))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                }
            }
            .padding(16)
        }
    }

    private func presetButton(_ title: String, index: Int) -> some View {
        Button {
            viewModel.setScenario(index)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(8)
        }
    }

    // MARK: - Tab 2: Context Resources

    private var resourcesTab: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.resources) { res in
                        Button {
                            viewModel.selectResource(res)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(res.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(viewModel.selectedResource?.uri == res.uri ? .white : .primary)
                                Text(res.uri)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(viewModel.selectedResource?.uri == res.uri ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(10)
                            .background(viewModel.selectedResource?.uri == res.uri ? Color.purple : Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            if let selected = viewModel.selectedResource {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .font(.system(size: 16, weight: .bold))
                            Text("URI: \(selected.uri)  •  MIME: \(selected.mimeType ?? "text/plain")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            viewModel.selectResource(selected)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                    }

                    if let desc = selected.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Text("Resource Context Payload (Injected into Model):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ScrollView {
                        Text(viewModel.selectedResourceContent)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding(16)
            } else {
                Spacer()
                Text("No resource selected")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Tab 3: Tools Registry

    private var toolsTab: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.tools) { tool in
                        Button {
                            viewModel.selectTool(tool)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 11))
                                Text(tool.name)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .padding(10)
                            .background(viewModel.selectedTool?.name == tool.name ? Color.purple : Color(.secondarySystemBackground))
                            .foregroundColor(viewModel.selectedTool?.name == tool.name ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            if let tool = viewModel.selectedTool {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.system(size: 16, weight: .bold))
                            Text(tool.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Text("Tool Arguments (JSON Schema)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 10) {
                            ForEach(Array(tool.inputSchema.properties.keys.sorted()), id: \.self) { argKey in
                                let prop = tool.inputSchema.properties[argKey]
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(argKey)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        if tool.inputSchema.required.contains(argKey) {
                                            Text("REQUIRED")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.red)
                                        }
                                        Spacer()
                                        if let type = prop?.type {
                                            Text(type)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    TextField(prop?.description ?? argKey, text: Binding(
                                        get: { viewModel.toolArguments[argKey] ?? "" },
                                        set: { viewModel.toolArguments[argKey] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13))
                                }
                            }
                        }

                        Button {
                            viewModel.executeSelectedTool()
                        } label: {
                            HStack {
                                if viewModel.isRunningTool {
                                    ProgressView().tint(.white)
                                    Text("Executing...")
                                } else {
                                    Image(systemName: "play.fill")
                                    Text("Call Tool via MCP 'tools/call'")
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isRunningTool)

                        if !viewModel.toolResultText.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MCP Output:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                Text(viewModel.toolResultText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                Spacer()
                Text("No tool selected")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Tab 4: Raw JSON-RPC Wire Inspector

    private var wireInspectorTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.wireMessages.count) JSON-RPC Messages")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Clear") {
                    viewModel.clearWireLogs()
                }
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))

            Divider()

            if viewModel.wireMessages.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No JSON-RPC messages yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Run the Agent Demo or execute a tool to see live wire traffic.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(viewModel.wireMessages) { msg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(msg.direction.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(msg.direction == .outgoing ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                                .foregroundColor(msg.direction == .outgoing ? .blue : .green)
                                .cornerRadius(4)

                            Text(msg.method)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))

                            Spacer()

                            Text(msg.timestamp, style: .time)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Text(msg.rawJSON)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                .listStyle(.plain)
            }
        }
    }
}
