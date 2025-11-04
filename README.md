# MCP Knowledge Base Server

A robust Ruby-based Knowledge Base server implementing the Model Context Protocol (MCP) with comprehensive error handling, validation, and a web interface.

## Overview

This server provides a complete knowledge base solution with:
- **MCP Protocol Support**: Full JSON-RPC 2.0 implementation for AI assistants
- **Web Interface**: HAML-based UI for creating and viewing articles
- **REST API**: JSON endpoints for programmatic access
- **RSS Feed**: Stay updated with the latest articles
- **Robust Error Handling**: Comprehensive validation and error handling throughout

## Features

### Current Features (Level 1 + Partial Level 2)
- ✅ Full MCP protocol implementation (JSON-RPC 2.0)
- ✅ SQLite database with Sequel ORM
- ✅ CRUD operations for articles
- ✅ Web interface with HAML templates
- ✅ RSS feed generation
- ✅ JSON API endpoints
- ✅ Basic search functionality
- ✅ **Comprehensive error handling and validation** (Level 2.1 - COMPLETED)
  - Custom error classes
  - Input validation and sanitization
  - Proper HTTP status codes
  - User-friendly error pages

### In Progress
- 🚧 Logging infrastructure (Level 2.1 - Next)

See [ProductRoadmap.md](ProductRoadmap.md) for the complete development roadmap.

## Requirements

- Ruby 3.0+
- SQLite3
- Bundler

## Installation

1. Clone the repository:
```bash
git clone https://github.com/grantbrewer/mcp-kb-server.git
cd mcp-kb-server
```

2. Install dependencies:
```bash
bundle install
```

3. Set up the database:
```bash
ruby config/database.rb
```

## Usage

### Starting the Server

```bash
ruby app.rb
```

The server will start on `http://localhost:4567`

### Endpoints

#### Web Interface
- `GET /` - API information
- `GET /new` - Create new article form
- `GET /articles` - View all articles
- `GET /articles/:id` - View single article
- `POST /articles` - Create new article

#### MCP Protocol
- `POST /mcp` - MCP JSON-RPC endpoint
  - Supports: `initialize`, `resources/list`, `resources/read`, `tools/list`, `tools/call`

#### REST API
- `GET /api/articles` - List all published articles
- `GET /api/articles/:id` - Get article by ID
- `GET /api/search?q=query` - Search articles

#### RSS Feed
- `GET /feed.xml` - RSS feed of latest articles

## MCP Protocol Usage

### Available Tools

1. **search_articles**: Search for articles in the knowledge base
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "search_articles",
    "arguments": {
      "query": "your search term"
    }
  }
}
```

2. **get_article_by_slug**: Get a specific article by its slug
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_article_by_slug",
    "arguments": {
      "slug": "article-slug"
    }
  }
}
```

### Resources

Articles are exposed as resources with URIs in the format: `kb://article/{id}`

## Error Handling

The application includes comprehensive error handling:

- **ValidationError** (422): Input validation failures
- **ArticleNotFoundError** (404): Resource not found
- **InvalidRequestError** (400): Malformed requests
- **DatabaseError** (500): Database operation failures
- **MCPError**: JSON-RPC protocol errors with proper error codes

All errors return structured JSON responses with helpful error messages.

## Project Structure

```
mcp-kb-server/
├── app.rb                    # Main Sinatra application
├── config/
│   └── database.rb          # Database configuration
├── db/
│   ├── migrations/          # Database migrations
│   └── knowledge_base.db    # SQLite database (created on first run)
├── lib/
│   ├── errors.rb           # Custom error classes
│   ├── models.rb           # Sequel models with validations
│   └── mcp_handler.rb      # MCP protocol handler
├── views/
│   ├── layout.haml         # Layout template
│   ├── new.haml            # Article creation form
│   ├── articles.haml       # Articles list
│   ├── show.haml           # Single article view
│   └── error.haml          # Error page
├── ProductRoadmap.md       # Development roadmap
└── README.md               # This file
```

## Database Schema

### Articles Table
- `id` - Primary key
- `title` - Article title (required, 3-255 chars)
- `slug` - URL-friendly slug (unique, auto-generated)
- `content` - Article content (required, min 10 chars)
- `author` - Author name
- `category` - Article category
- `tags` - Comma-separated tags
- `is_published` - Publication status
- `published_at` - Publication timestamp
- `created_at` - Creation timestamp
- `updated_at` - Last update timestamp

## Development Roadmap

This project follows a progressive enhancement strategy from MVP to production-grade code. See [ProductRoadmap.md](ProductRoadmap.md) for details on:

- **Level 1**: Minimalist MVP (✅ Complete)
- **Level 2**: Robust Development-Ready Code (🚧 In Progress)
  - Step 1: Error Handling & Validation (✅ Complete)
  - Step 2: Logging (Next)
  - Steps 3-8: Testing, Configuration, Security, etc.
- **Level 3**: Production-Grade Code (Planned)

## Testing Examples

```bash
# Test JSON API
curl http://localhost:4567/api/articles

# Test search
curl "http://localhost:4567/api/search?q=ruby"

# Test RSS feed
curl http://localhost:4567/feed.xml

# Test MCP initialize
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{}}}'

# Test MCP resources list
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"resources/list"}'

# Test MCP search tool
curl -X POST http://localhost:4567/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search_articles","arguments":{"query":"ruby"}}}'
```

## Contributing

Contributions are welcome! Please follow these guidelines:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Author

Grant Brewer

## Acknowledgments

Built with:
- [Sinatra](http://sinatrarb.com/) - Web framework
- [Sequel](http://sequel.jeremyevans.net/) - Database ORM
- [SQLite](https://www.sqlite.org/) - Database
- [HAML](http://haml.info/) - Template engine
