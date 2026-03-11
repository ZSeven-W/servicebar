import Foundation

enum MCPStatus: String, Codable {
    case installed = "installed"
    case notInstalled = "not_installed"
    case error = "error"
}

enum MCPAgentType: String, Codable, CaseIterable {
    case claudeCode = "claude-code"
    case codex = "codex"
    case opencode = "opencode"
    
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .opencode: return "OpenCode"
        }
    }
    
    var configFileName: String {
        switch self {
        case .claudeCode: return ".claude.json"
        case .codex: return ".codex.json"
        case .opencode: return ".opencode.json"
        }
    }
    
    var configPath: String {
        return NSHomeDirectory() + "/" + configFileName
    }
}

struct MCPServer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let agentType: MCPAgentType
    let installCommand: String
    var status: MCPStatus
    let description: String
    let packageName: String
    let npmPackage: String?
    
    init(
        id: String,
        name: String,
        agentType: MCPAgentType,
        installCommand: String,
        status: MCPStatus = .notInstalled,
        description: String,
        packageName: String,
        npmPackage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.agentType = agentType
        self.installCommand = installCommand
        self.status = status
        self.description = description
        self.packageName = packageName
        self.npmPackage = npmPackage
    }
}

// MARK: - Predefined MCP Servers

struct MCPServerRegistry {
    static let allServers: [MCPServer] = claudeCodeServers + codexServers + opencodeServers
    
    static let claudeCodeServers: [MCPServer] = [
        MCPServer(
            id: "claude-code-filesystem",
            name: "filesystem",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-filesystem",
            description: "Read, edit, and search local files",
            packageName: "@modelcontextprotocol/server-filesystem",
            npmPackage: "@modelcontextprotocol/server-filesystem"
        ),
        MCPServer(
            id: "claude-code-memory",
            name: "memory",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-memory",
            description: "Knowledge graph with persistent memory",
            packageName: "@modelcontextprotocol/server-memory",
            npmPackage: "@modelcontextprotocol/server-memory"
        ),
        MCPServer(
            id: "claude-code-github",
            name: "github",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-github",
            description: "Interact with GitHub API and repositories",
            packageName: "@modelcontextprotocol/server-github",
            npmPackage: "@modelcontextprotocol/server-github"
        ),
        MCPServer(
            id: "claude-code-slack",
            name: "slack",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-slack",
            description: "Send messages and manage Slack channels",
            packageName: "@modelcontextprotocol/server-slack",
            npmPackage: "@modelcontextprotocol/server-slack"
        ),
        MCPServer(
            id: "claude-code-notion",
            name: "notion",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-notion",
            description: "Interact with Notion pages and databases",
            packageName: "@modelcontextprotocol/server-notion",
            npmPackage: "@modelcontextprotocol/server-notion"
        ),
        MCPServer(
            id: "claude-code-google-maps",
            name: "google-maps",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-google-maps",
            description: "Get location details and directions",
            packageName: "@modelcontextprotocol/server-google-maps",
            npmPackage: "@modelcontextprotocol/server-google-maps"
        ),
        MCPServer(
            id: "claude-code-puppeteer",
            name: "puppeteer",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-puppeteer",
            description: "Browser automation with Chrome",
            packageName: "@modelcontextprotocol/server-puppeteer",
            npmPackage: "@modelcontextprotocol/server-puppeteer"
        ),
        MCPServer(
            id: "claude-code-sequential-thinking",
            name: "sequential-thinking",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-sequential-thinking",
            description: "Use a structured thinking tool for complex reasoning",
            packageName: "@modelcontextprotocol/server-sequential-thinking",
            npmPackage: "@modelcontextprotocol/server-sequential-thinking"
        ),
        MCPServer(
            id: "claude-code-brave-search",
            name: "brave-search",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-brave-search",
            description: "Search the web using Brave Search API",
            packageName: "@modelcontextprotocol/server-brave-search",
            npmPackage: "@modelcontextprotocol/server-brave-search"
        ),
        MCPServer(
            id: "claude-code-everything",
            name: "everything",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-everything",
            description: "Filesystem, Git, and more operations",
            packageName: "@modelcontextprotocol/server-everything",
            npmPackage: "@modelcontextprotocol/server-everything"
        ),
        MCPServer(
            id: "claude-code-sqlite",
            name: "sqlite",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-sqlite",
            description: "Query and manipulate SQLite databases",
            packageName: "@modelcontextprotocol/server-sqlite",
            npmPackage: "@modelcontextprotocol/server-sqlite"
        ),
        MCPServer(
            id: "claude-code-fetch",
            name: "fetch",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-fetch",
            description: "Fetch web content and APIs",
            packageName: "@modelcontextprotocol/server-fetch",
            npmPackage: "@modelcontextprotocol/server-fetch"
        ),
        MCPServer(
            id: "claude-code-aws-kb-retrieval",
            name: "aws-kb-retrieval",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-aws-kb-retrieval",
            description: "Query AWS Knowledge Base",
            packageName: "@modelcontextprotocol/server-aws-kb-retrieval",
            npmPackage: "@modelcontextprotocol/server-aws-kb-retrieval"
        ),
        MCPServer(
            id: "claude-code-gitlab",
            name: "gitlab",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-gitlab",
            description: "Interact with GitLab projects and MRs",
            packageName: "@modelcontextprotocol/server-gitlab",
            npmPackage: "@modelcontextprotocol/server-gitlab"
        ),
        MCPServer(
            id: "claude-code-sentry",
            name: "sentry",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-sentry",
            description: "Query Sentry errors and issues",
            packageName: "@modelcontextprotocol/server-sentry",
            npmPackage: "@modelcontextprotocol/server-sentry"
        ),
        MCPServer(
            id: "claude-code-git",
            name: "git",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-git",
            description: "Git operations and repository management",
            packageName: "@modelcontextprotocol/server-git",
            npmPackage: "@modelcontextprotocol/server-git"
        ),
        MCPServer(
            id: "claude-code-npm",
            name: "npm",
            agentType: .claudeCode,
            installCommand: "npm install -g @modelcontextprotocol/server-npm",
            description: "Search and manage npm packages",
            packageName: "@modelcontextprotocol/server-npm",
            npmPackage: "@modelcontextprotocol/server-npm"
        )
    ]
    
    static let codexServers: [MCPServer] = [
        MCPServer(
            id: "codex-filesystem",
            name: "filesystem",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-filesystem",
            description: "Read, edit, and search local files",
            packageName: "@anthropic-ai/mcp-server-filesystem",
            npmPackage: "@anthropic-ai/mcp-server-filesystem"
        ),
        MCPServer(
            id: "codex-memory",
            name: "memory",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-memory",
            description: "Knowledge graph with persistent memory",
            packageName: "@anthropic-ai/mcp-server-memory",
            npmPackage: "@anthropic-ai/mcp-server-memory"
        ),
        MCPServer(
            id: "codex-github",
            name: "github",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-github",
            description: "Interact with GitHub API and repositories",
            packageName: "@anthropic-ai/mcp-server-github",
            npmPackage: "@anthropic-ai/mcp-server-github"
        ),
        MCPServer(
            id: "codex-postgres",
            name: "postgres",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-postgres",
            description: "Query PostgreSQL databases",
            packageName: "@anthropic-ai/mcp-server-postgres",
            npmPackage: "@anthropic-ai/mcp-server-postgres"
        ),
        MCPServer(
            id: "codex-mysql",
            name: "mysql",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-mysql",
            description: "Query MySQL databases",
            packageName: "@anthropic-ai/mcp-server-mysql",
            npmPackage: "@anthropic-ai/mcp-server-mysql"
        ),
        MCPServer(
            id: "codex-sqlite",
            name: "sqlite",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-sqlite",
            description: "Query SQLite databases",
            packageName: "@anthropic-ai/mcp-server-sqlite",
            npmPackage: "@anthropic-ai/mcp-server-sqlite"
        ),
        MCPServer(
            id: "codex-puppeteer",
            name: "puppeteer",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-puppeteer",
            description: "Browser automation with Chrome",
            packageName: "@anthropic-ai/mcp-server-puppeteer",
            npmPackage: "@anthropic-ai/mcp-server-puppeteer"
        ),
        MCPServer(
            id: "codex-brave-search",
            name: "brave-search",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-brave-search",
            description: "Search the web using Brave Search API",
            packageName: "@anthropic-ai/mcp-server-brave-search",
            npmPackage: "@anthropic-ai/mcp-server-brave-search"
        ),
        MCPServer(
            id: "codex-fetch",
            name: "fetch",
            agentType: .codex,
            installCommand: "npm install -g @anthropic-ai/mcp-server-fetch",
            description: "Fetch web content and APIs",
            packageName: "@anthropic-ai/mcp-server-fetch",
            npmPackage: "@anthropic-ai/mcp-server-fetch"
        )
    ]
    
    static let opencodeServers: [MCPServer] = [
        MCPServer(
            id: "opencode-filesystem",
            name: "filesystem",
            agentType: .opencode,
            installCommand: "npm install -g @opencode/mcp-server-filesystem",
            description: "Read, edit, and search local files",
            packageName: "@opencode/mcp-server-filesystem",
            npmPackage: "@opencode/mcp-server-filesystem"
        ),
        MCPServer(
            id: "opencode-memory",
            name: "memory",
            agentType: .opencode,
            installCommand: "npm install -g @opencode/mcp-server-memory",
            description: "Knowledge graph with persistent memory",
            packageName: "@opencode/mcp-server-memory",
            npmPackage: "@opencode/mcp-server-memory"
        ),
        MCPServer(
            id: "opencode-github",
            name: "github",
            agentType: .opencode,
            installCommand: "npm install -g @opencode/mcp-server-github",
            description: "Interact with GitHub API and repositories",
            packageName: "@opencode/mcp-server-github",
            npmPackage: "@opencode/mcp-server-github"
        ),
        MCPServer(
            id: "opencode-fetch",
            name: "fetch",
            agentType: .opencode,
            installCommand: "npm install -g @opencode/mcp-server-fetch",
            description: "Fetch web content and APIs",
            packageName: "@opencode/mcp-server-fetch",
            npmPackage: "@opencode/mcp-server-fetch"
        ),
        MCPServer(
            id: "opencode-git",
            name: "git",
            agentType: .opencode,
            installCommand: "npm install -g @opencode/mcp-server-git",
            description: "Git operations and repository management",
            packageName: "@opencode/mcp-server-git",
            npmPackage: "@opencode/mcp-server-git"
        )
    ]
    
    static func servers(for agentType: MCPAgentType) -> [MCPServer] {
        switch agentType {
        case .claudeCode: return claudeCodeServers
        case .codex: return codexServers
        case .opencode: return opencodeServers
        }
    }
}
