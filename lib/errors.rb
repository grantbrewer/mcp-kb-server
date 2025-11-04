# Custom error classes for the Knowledge Base application

class KnowledgeBaseError < StandardError
  attr_reader :status_code, :error_code

  def initialize(message, status_code: 500, error_code: 'internal_error')
    @status_code = status_code
    @error_code = error_code
    super(message)
  end
end

class ArticleNotFoundError < KnowledgeBaseError
  def initialize(message = 'Article not found')
    super(message, status_code: 404, error_code: 'article_not_found')
  end
end

class ValidationError < KnowledgeBaseError
  attr_reader :validation_errors

  def initialize(message = 'Validation failed', validation_errors: {})
    @validation_errors = validation_errors
    super(message, status_code: 422, error_code: 'validation_error')
  end
end

class MCPError < KnowledgeBaseError
  attr_reader :rpc_error_code

  def initialize(message, rpc_error_code: -32603)
    @rpc_error_code = rpc_error_code
    super(message, status_code: 400, error_code: 'mcp_error')
  end
end

class InvalidRequestError < KnowledgeBaseError
  def initialize(message = 'Invalid request')
    super(message, status_code: 400, error_code: 'invalid_request')
  end
end

class DatabaseError < KnowledgeBaseError
  def initialize(message = 'Database operation failed')
    super(message, status_code: 500, error_code: 'database_error')
  end
end
