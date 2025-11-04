require_relative '../models/article'
require_relative '../lib/errors'
require 'json'

class MCPRequestHandler
  def self.handle(request_body)
    request = JSON.parse(request_body)

    # Validate JSON-RPC structure
    validate_jsonrpc_request(request)

    method = request['method']
    params = request['params'] || {}
    id = request['id']

    # Handle different MCP methods
    result = case method
    when 'resources/list'
      list_resources
    when 'resources/read'
      read_resource(params)
    when 'tools/list'
      list_tools
    when 'tools/call'
      call_tool(params)
    else
      raise MCPError.new("Method not found: #{method}", code: -32601)
    end

    # Return JSON-RPC success response
    jsonrpc_success_response(id, result)
  rescue JSON::ParserError => e
    jsonrpc_error_response(nil, -32700, 'Parse error', e.message)
  rescue InvalidRequestError => e
    jsonrpc_error_response(request['id'], -32600, 'Invalid Request', e.message)
  rescue MCPError => e
    jsonrpc_error_response(request['id'], e.code, e.message, e.details)
  rescue StandardError => e
    jsonrpc_error_response(request['id'], -32603, 'Internal error', e.message)
  end

  private

  def self.validate_jsonrpc_request(request)
    raise InvalidRequestError.new('Request must be a Hash') unless request.is_a?(Hash)
    raise InvalidRequestError.new('Missing jsonrpc field') unless request['jsonrpc']
    raise InvalidRequestError.new('Invalid jsonrpc version (must be "2.0")') unless request['jsonrpc'] == '2.0'
    raise InvalidRequestError.new('Missing method field') unless request['method']
    raise InvalidRequestError.new('Method must be a string') unless request['method'].is_a?(String)
  end

  def self.list_resources
    articles = Article.published.not_deleted.recent.all

    {
      resources: articles.map { |article|
        {
          uri: "kb://article/#{article.slug}",
          name: article.title,
          description: article.content[0..200],
          mimeType: "text/plain"
        }
      }
    }
  end

  def self.read_resource(params)
    uri = params['uri']
    raise InvalidRequestError.new('Missing uri parameter') unless uri

    # Extract slug from URI (kb://article/slug)
    unless uri =~ /^kb:\/\/article\/(.+)$/
      raise InvalidRequestError.new('Invalid URI format. Expected: kb://article/{slug}')
    end

    slug = $1
    article = Article.published.not_deleted.where(slug: slug).first

    raise ArticleNotFoundError.new("Article not found: #{slug}") unless article

    {
      contents: [
        {
          uri: uri,
          mimeType: "text/plain",
          text: "# #{article.title}\n\n#{article.content}\n\nAuthor: #{article.author || 'Unknown'}\nCategory: #{article.category || 'Uncategorized'}\nTags: #{article.tags || 'None'}\nPublished: #{article.published_at}"
        }
      ]
    }
  end

  def self.list_tools
    {
      tools: [
        {
          name: "search_articles",
          description: "Search for articles in the knowledge base",
          inputSchema: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search query"
              },
              category: {
                type: "string",
                description: "Filter by category (optional)"
              }
            },
            required: ["query"]
          }
        },
        {
          name: "get_article",
          description: "Get a specific article by slug",
          inputSchema: {
            type: "object",
            properties: {
              slug: {
                type: "string",
                description: "Article slug"
              }
            },
            required: ["slug"]
          }
        }
      ]
    }
  end

  def self.call_tool(params)
    tool_name = params['name']
    arguments = params['arguments'] || {}

    case tool_name
    when 'search_articles'
      search_articles_tool(arguments)
    when 'get_article'
      get_article_tool(arguments)
    else
      raise MCPError.new("Tool not found: #{tool_name}", code: -32601)
    end
  end

  def self.search_articles_tool(arguments)
    query = arguments['query']
    raise InvalidRequestError.new('Missing query argument') unless query

    service = SearchService.new(query, {
      category: arguments['category'],
      published_only: true,
      include_deleted: false,
      page: 1,
      per_page: 10
    })

    result = service.search

    {
      content: [
        {
          type: "text",
          text: "Found #{result[:meta][:total]} articles:\n\n" +
                result[:articles].map { |a|
                  "- #{a.title} (#{a.slug})\n  Category: #{a.category || 'None'}\n  #{a.content[0..100]}..."
                }.join("\n\n")
        }
      ]
    }
  end

  def self.get_article_tool(arguments)
    slug = arguments['slug']
    raise InvalidRequestError.new('Missing slug argument') unless slug

    article = Article.published.not_deleted.where(slug: slug).first
    raise ArticleNotFoundError.new("Article not found: #{slug}") unless article

    {
      content: [
        {
          type: "text",
          text: "# #{article.title}\n\n#{article.content}\n\nAuthor: #{article.author || 'Unknown'}\nCategory: #{article.category || 'Uncategorized'}\nTags: #{article.tags || 'None'}\nPublished: #{article.published_at}"
        }
      ]
    }
  end

  def self.jsonrpc_success_response(id, result)
    JSON.generate({
      jsonrpc: "2.0",
      id: id,
      result: result
    })
  end

  def self.jsonrpc_error_response(id, code, message, data = nil)
    response = {
      jsonrpc: "2.0",
      id: id,
      error: {
        code: code,
        message: message
      }
    }
    response[:error][:data] = data if data

    JSON.generate(response)
  end
end
