# MCP Protocol Documentation

## Overview

The MCP (Model Context Protocol) endpoint provides a JSON-RPC 2.0 interface for AI models like Claude to interact with the knowledge base. This protocol allows models to discover, read, and search articles as resources.

**Endpoint:** `POST /mcp`

**Protocol:** JSON-RPC 2.0

---

## JSON-RPC 2.0 Format

All MCP requests and responses follow the JSON-RPC 2.0 specification.

### Request Format

```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": { /* method parameters */ },
  "id": 1
}
```

### Success Response Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { /* method result */ }
}
```

### Error Response Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "Invalid Request",
    "data": "Additional error details"
  }
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Missing required fields |
| -32601 | Method not found | Unknown method |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Server error |

---

## MCP Methods

### 1. resources/list

List all available articles as resources.

**Method:** `resources/list`

**Parameters:** None

**Request Example:**

```json
{
  "jsonrpc": "2.0",
  "method": "resources/list",
  "params": {},
  "id": 1
}
```

**Response Example:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "resources": [
      {
        "uri": "kb://article/getting-started",
        "name": "Getting Started",
        "description": "This guide will help you get started with...",
        "mimeType": "text/plain"
      },
      {
        "uri": "kb://article/advanced-features",
        "name": "Advanced Features",
        "description": "Learn about advanced features including...",
        "mimeType": "text/plain"
      }
    ]
  }
}
```

**Resource URI Format:** `kb://article/{slug}`

**Notes:**
- Only published articles are returned
- Soft-deleted articles are excluded
- Articles are ordered by published date (newest first)
- Description is truncated to first 200 characters

---

### 2. resources/read

Read the full content of a specific article.

**Method:** `resources/read`

**Parameters:**
- `uri` (string, required) - Resource URI in format `kb://article/{slug}`

**Request Example:**

```json
{
  "jsonrpc": "2.0",
  "method": "resources/read",
  "params": {
    "uri": "kb://article/getting-started"
  },
  "id": 2
}
```

**Response Example:**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "contents": [
      {
        "uri": "kb://article/getting-started",
        "mimeType": "text/plain",
        "text": "# Getting Started\n\nThis guide will help you get started with our knowledge base.\n\nAuthor: John Doe\nCategory: Tutorial\nTags: guide, beginner\nPublished: 2024-11-04 12:00:00 UTC"
      }
    ]
  }
}
```

**Error Cases:**

Invalid URI format (400):
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32600,
    "message": "Invalid Request",
    "data": "Invalid URI format. Expected: kb://article/{slug}"
  }
}
```

Article not found (404):
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": "Article not found: unknown-slug"
  }
}
```

---

### 3. tools/list

List available tools (functions) that can be called.

**Method:** `tools/list`

**Parameters:** None

**Request Example:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 3
}
```

**Response Example:**

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "tools": [
      {
        "name": "search_articles",
        "description": "Search for articles in the knowledge base",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Search query"
            },
            "category": {
              "type": "string",
              "description": "Filter by category (optional)"
            }
          },
          "required": ["query"]
        }
      },
      {
        "name": "get_article",
        "description": "Get a specific article by slug",
        "inputSchema": {
          "type": "object",
          "properties": {
            "slug": {
              "type": "string",
              "description": "Article slug"
            }
          },
          "required": ["slug"]
        }
      }
    ]
  }
}
```

---

### 4. tools/call

Call a specific tool.

**Method:** `tools/call`

**Parameters:**
- `name` (string, required) - Tool name
- `arguments` (object, required) - Tool-specific arguments

---

#### Tool: search_articles

Search for articles in the knowledge base.

**Request Example:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "search_articles",
    "arguments": {
      "query": "docker tutorial",
      "category": "DevOps"
    }
  },
  "id": 4
}
```

**Response Example:**

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Found 3 articles:\n\n- Docker Getting Started (docker-getting-started)\n  Category: DevOps\n  This comprehensive guide covers Docker basics including installation, containers, and images...\n\n- Docker Compose Tutorial (docker-compose-tutorial)\n  Category: DevOps\n  Learn how to use Docker Compose to define and run multi-container Docker applications...\n\n- Advanced Docker Networking (advanced-docker-networking)\n  Category: DevOps\n  Deep dive into Docker networking concepts including bridge networks, overlay networks..."
      }
    ]
  }
}
```

**Arguments:**
- `query` (string, required) - Search query
- `category` (string, optional) - Filter by category

**Notes:**
- Returns up to 10 results
- Only searches published articles
- Uses FTS5 full-text search
- Results ordered by published date

---

#### Tool: get_article

Get a specific article by slug.

**Request Example:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_article",
    "arguments": {
      "slug": "docker-getting-started"
    }
  },
  "id": 5
}
```

**Response Example:**

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "# Docker Getting Started\n\nThis comprehensive guide covers Docker basics including installation, containers, and images.\n\nAuthor: DevOps Team\nCategory: DevOps\nTags: docker, containers, tutorial\nPublished: 2024-11-04 10:00:00 UTC"
      }
    ]
  }
}
```

**Arguments:**
- `slug` (string, required) - Article slug

**Error Case - Article Not Found:**

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": "Article not found: unknown-slug"
  }
}
```

---

## Complete Usage Example

### Workflow: Search and Read Articles

```bash
# 1. List all available resources
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/list",
    "params": {},
    "id": 1
  }'

# 2. Search for specific articles
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "search_articles",
      "arguments": {
        "query": "API documentation"
      }
    },
    "id": 2
  }'

# 3. Read a specific article
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/read",
    "params": {
      "uri": "kb://article/api-documentation"
    },
    "id": 3
  }'

# 4. Get article by slug using tool
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_article",
      "arguments": {
        "slug": "api-documentation"
      }
    },
    "id": 4
  }'
```

---

## Best Practices

### For AI Models (Claude, etc.)

1. **Discovery First**: Start with `resources/list` to discover available content
2. **Search When Appropriate**: Use `search_articles` tool when user asks for specific topics
3. **Read Full Content**: Use `resources/read` or `get_article` to get complete article text
4. **Handle Errors**: Check for error responses and provide helpful feedback to users

### For API Clients

1. **Include ID**: Always include a unique `id` in requests to match responses
2. **Check jsonrpc**: Verify `jsonrpc` field is set to `"2.0"`
3. **Validate URIs**: Ensure URIs follow the format `kb://article/{slug}`
4. **Handle Errors**: Implement proper error handling for all error codes

---

## Differences from REST API

| Feature | MCP Protocol | REST API |
|---------|-------------|----------|
| **Protocol** | JSON-RPC 2.0 | HTTP REST |
| **Endpoint** | Single POST /mcp | Multiple GET/POST/PATCH/DELETE |
| **Authentication** | Built for AI models | Built for web clients |
| **Response Format** | JSON-RPC result/error | {data, meta, errors} |
| **Resource Model** | URI-based (kb://article/slug) | ID and slug-based URLs |
| **Use Case** | AI model integration | Web/mobile apps |

---

## Integration with Claude

The MCP protocol is specifically designed for integration with Claude and other AI models. When configured as an MCP server:

1. Claude discovers available articles via `resources/list`
2. Claude can search articles using the `search_articles` tool
3. Claude can read full article content via `resources/read`
4. Claude presents information to users in natural language

**Configuration Example:**

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "knowledge-base": {
      "url": "http://localhost:4567/mcp",
      "transport": "http"
    }
  }
}
```

---

## Troubleshooting

### Common Issues

**1. Parse Error (-32700)**
- Check that request body is valid JSON
- Ensure proper Content-Type header: `application/json`

**2. Invalid Request (-32600)**
- Verify `jsonrpc: "2.0"` is present
- Ensure `method` field exists and is a string
- Check that request structure is correct

**3. Method Not Found (-32601)**
- Verify method name is correct (case-sensitive)
- Supported methods: `resources/list`, `resources/read`, `tools/list`, `tools/call`

**4. Invalid Params (-32602)**
- Check required parameters are provided
- Verify parameter types match schema
- For URIs, ensure format is `kb://article/{slug}`

---

## Version History

### Version 2.0.0 (Current)
- Initial MCP protocol implementation
- Support for resources/list and resources/read
- Support for tools/list and tools/call
- search_articles and get_article tools
- Full-text search with FTS5

---

## Support

For questions or issues with the MCP protocol:
1. Check this documentation
2. Review the JSON-RPC 2.0 specification
3. Refer to the main API documentation
4. Open an issue on the project repository
