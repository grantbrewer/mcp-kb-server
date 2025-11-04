# Error handlers for Sinatra application
# This module configures error handling for different error types

module ErrorHandlers
  def self.registered(app)
    # ValidationError handler (422 Unprocessable Entity)
    app.error ValidationError do
      err = env['sinatra.error']
      status err.status_code
      content_type :json
      json({
        error: err.error_code,
        message: err.message,
        validation_errors: err.validation_errors
      })
    end

    # ArticleNotFoundError handler (404 Not Found)
    app.error ArticleNotFoundError do
      err = env['sinatra.error']
      status err.status_code
      content_type :json
      json({
        error: err.error_code,
        message: err.message
      })
    end

    # InvalidRequestError handler (400 Bad Request)
    app.error InvalidRequestError do
      err = env['sinatra.error']
      status err.status_code
      content_type :json
      json({
        error: err.error_code,
        message: err.message
      })
    end

    # DatabaseError handler (500 Internal Server Error)
    app.error DatabaseError do
      err = env['sinatra.error']
      status err.status_code
      content_type :json
      json({
        error: err.error_code,
        message: err.message
      })
    end

    # Generic KnowledgeBaseError handler
    app.error KnowledgeBaseError do
      err = env['sinatra.error']
      status err.status_code
      content_type :json
      json({
        error: err.error_code,
        message: err.message
      })
    end

    # Generic StandardError handler for unexpected errors (500)
    app.error StandardError do
      err = env['sinatra.error']
      status 500
      content_type :json
      json({
        error: 'internal_error',
        message: 'An unexpected error occurred',
        details: err.message
      })
    end

    # 404 Not Found handler
    app.not_found do
      content_type :json
      json({
        error: 'not_found',
        message: 'The requested resource was not found'
      })
    end
  end
end
