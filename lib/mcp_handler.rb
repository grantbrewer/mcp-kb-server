require 'json'
require_relative 'models'
require_relative 'errors'

class MCPHandler
  PROTOCOL_VERSION = '2025-06-18'

  def self.handle(request_body)
    begin
      # Validate request body is not empty
      if request_body.nil? || request_body.strip.empty?
        raise MCPError.new('Request body cannot be empty', rpc_error_code: -32700)
      end

      # Parse JSON request
      request = JSON.parse(request_body)

      # Validate JSON-RPC structure
      unless request.is_a?(Hash)
        raise MCPError.new('Request must be a JSON object', rpc_error_code: -32600)
      end

      unless request['jsonrpc'] == '2.0'
        raise MCPError.new('Invalid JSON-RPC version. Must be "2.0"', rpc_error_code: -32600)
      end

      unless request['method'].is_a?(String)
        raise MCPError.new('Method must be a string', rpc_error_code: -32600)
      end

      # Route to appropriate handler
      response = case request['method']
      when 'initialize'
        handle_initialize(request)
      when 'resources/list'
        handle_resources_list(request)
      when 'resources/read'
        handle_resources_read(request)
      when 'tools/list'
        handle_tools_list(request)
      when 'tools/call'
        handle_tools_call(request)
      else
        error_response(request['id'], -32601, 'Method not found')
      end

      response.to_json
    rescue JSON::ParserError => e
      error_response(nil, -32700, "Parse error: #{e.message}").to_json
    rescue MCPError => e
      error_response(request&.dig('id'), e.rpc_error_code, e.message).to_json
    rescue DatabaseError => e
      error_response(request&.dig('id'), -32603, e.message).to_json
    rescue StandardError => e
      error_response(request&.dig('id'), -32603, "Internal error: #{e.message}").to_json
    end
  end

  def self.handle_initialize(request)
    {
      jsonrpc: '2.0',
      id: request['id'],
      result: {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          resources: {},
          tools: {}
        },
        serverInfo: {
          name: 'Knowledge Base MCP Server',
          version: '1.0.0'
        }
      }
    }
  end

  def self.handle_resources_list(request)
    begin
      articles = Article.where(is_published: true).all

      resources = articles.map do |article|
        {
          uri: "kb://article/#{article.id}",
          name: article.title,
          description: (article.content&.[](0..100) || '') + '...',
          mimeType: 'text/plain'
        }
      end

      {
        jsonrpc: '2.0',
        id: request['id'],
        result: {
          resources: resources
        }
      }
    rescue DatabaseError => e
      error_response(request['id'], -32603, "Database error: #{e.message}")
    rescue StandardError => e
      error_response(request['id'], -32603, "Error listing resources: #{e.message}")
    end
  end

  def self.handle_resources_read(request)
    begin
      uri = request.dig('params', 'uri')

      # Validate URI parameter
      unless uri.is_a?(String) && !uri.empty?
        raise MCPError.new('URI parameter is required and must be a non-empty string', rpc_error_code: -32602)
      end

      # Extract article ID from URI
      article_id = uri.match(/kb:\/\/article\/(\d+)/)&.[](1)

      unless article_id
        raise MCPError.new('Invalid URI format. Expected: kb://article/{id}', rpc_error_code: -32602)
      end

      article = Article[article_id.to_i]

      unless article
        raise ArticleNotFoundError.new("Article not found for URI: #{uri}")
      end

      {
        jsonrpc: '2.0',
        id: request['id'],
        result: {
          contents: [
            {
              uri: uri,
              mimeType: 'text/plain',
              text: "# #{article.title}\n\nAuthor: #{article.author}\nCategory: #{article.category}\nTags: #{article.tags}\n\n#{article.content}"
            }
          ]
        }
      }
    rescue ArticleNotFoundError => e
      error_response(request['id'], -32602, e.message)
    rescue MCPError => e
      error_response(request['id'], e.rpc_error_code, e.message)
    rescue DatabaseError => e
      error_response(request['id'], -32603, "Database error: #{e.message}")
    rescue StandardError => e
      error_response(request['id'], -32603, "Error reading resource: #{e.message}")
    end
  end

  def self.handle_tools_list(request)
    {
      jsonrpc: '2.0',
      id: request['id'],
      result: {
        tools: [
          {
            name: 'search_articles',
            description: 'Search for articles in the knowledge base',
            inputSchema: {
              type: 'object',
              properties: {
                query: {
                  type: 'string',
                  description: 'Search query to find articles'
                }
              },
              required: ['query']
            }
          },
          {
            name: 'get_article_by_slug',
            description: 'Get a specific article by its slug',
            inputSchema: {
              type: 'object',
              properties: {
                slug: {
                  type: 'string',
                  description: 'The slug of the article'
                }
              },
              required: ['slug']
            }
          }
        ]
      }
    }
  end

  def self.handle_tools_call(request)
    begin
      tool_name = request.dig('params', 'name')
      arguments = request.dig('params', 'arguments') || {}

      # Validate tool name
      unless tool_name.is_a?(String) && !tool_name.empty?
        raise MCPError.new('Tool name is required and must be a non-empty string', rpc_error_code: -32602)
      end

      # Validate arguments
      unless arguments.is_a?(Hash)
        raise MCPError.new('Arguments must be an object', rpc_error_code: -32602)
      end

      result = case tool_name
      when 'search_articles'
        search_articles(arguments['query'])
      when 'get_article_by_slug'
        get_article_by_slug(arguments['slug'])
      else
        raise MCPError.new("Unknown tool: #{tool_name}", rpc_error_code: -32602)
      end

      {
        jsonrpc: '2.0',
        id: request['id'],
        result: {
          content: [
            {
              type: 'text',
              text: result
            }
          ]
        }
      }
    rescue MCPError => e
      error_response(request['id'], e.rpc_error_code, e.message)
    rescue InvalidRequestError => e
      error_response(request['id'], -32602, e.message)
    rescue DatabaseError => e
      error_response(request['id'], -32603, "Database error: #{e.message}")
    rescue StandardError => e
      error_response(request['id'], -32603, "Error calling tool: #{e.message}")
    end
  end

  def self.search_articles(query)
    # Validate query parameter
    unless query.is_a?(String) && !query.strip.empty?
      raise InvalidRequestError.new('Query parameter is required and must be a non-empty string')
    end

    # Sanitize query to prevent SQL injection (Sequel handles this, but we validate format)
    if query.length > 255
      raise InvalidRequestError.new('Query parameter must be less than 255 characters')
    end

    articles = Article.search(query).where(is_published: true).all

    if articles.empty?
      "No articles found for query: #{query}"
    else
      results = articles.map do |a|
        content_preview = (a.content&.[](0..100) || '').gsub(/\n/, ' ')
        "- #{a.title} (#{a.slug})\n  Category: #{a.category}\n  #{content_preview}..."
      end.join("\n\n")

      "Found #{articles.count} article(s):\n\n#{results}"
    end
  end

  def self.get_article_by_slug(slug)
    # Validate slug parameter
    unless slug.is_a?(String) && !slug.strip.empty?
      raise InvalidRequestError.new('Slug parameter is required and must be a non-empty string')
    end

    # Validate slug format
    unless slug.match?(/\A[a-z0-9-]+\z/)
      raise InvalidRequestError.new('Slug must contain only lowercase letters, numbers, and hyphens')
    end

    article = Article.where(slug: slug, is_published: true).first

    unless article
      raise ArticleNotFoundError.new("Article not found: #{slug}")
    end

    "# #{article.title}\n\nAuthor: #{article.author}\nCategory: #{article.category}\nTags: #{article.tags}\nPublished: #{article.published_at}\n\n#{article.content}"
  end

  def self.error_response(id, code, message)
    {
      jsonrpc: '2.0',
      id: id,
      error: {
        code: code,
        message: message
      }
    }
  end
end
