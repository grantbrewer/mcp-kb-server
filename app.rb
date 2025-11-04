require 'sinatra'
require 'sinatra/json'
require 'json'
require 'builder'
require 'haml'
require_relative 'models/article'
require_relative 'services/article_creator'
require_relative 'services/article_publisher'
require_relative 'services/search_service'
require_relative 'services/mcp_request_handler'
require_relative 'lib/mcp_handler'
require_relative 'lib/errors'
require_relative 'lib/error_handlers'
require_relative 'lib/helpers'

set :port, 4567
set :bind, '0.0.0.0'
set :show_exceptions, false

# Register error handlers and helpers
register ErrorHandlers
helpers Helpers

# MCP Protocol endpoint
post '/mcp' do
  content_type :json

  request.body.rewind
  body = request.body.read

  MCPRequestHandler.handle(body)
end

# ============================================================
# API v1 - Versioned API with consistent response formatting
# ============================================================

# Helper method for consistent API v1 responses
helpers do
  def api_v1_response(data, meta = {}, status_code = 200)
    status status_code
    content_type :json
    json({
      data: data,
      meta: meta
    })
  end

  def api_v1_error(message, errors = {}, status_code = 400)
    status status_code
    content_type :json
    json({
      errors: {
        message: message,
        details: errors
      }
    })
  end

  def serialize_article(article)
    {
      id: article.id,
      title: article.title,
      slug: article.slug,
      content: article.content,
      author: article.author,
      category: article.category,
      tags: article.tag_list,
      published_at: article.published_at,
      created_at: article.created_at,
      updated_at: article.updated_at,
      is_published: article.is_published
    }
  end
end

# GET /api/v1/articles - List all articles with pagination
get '/api/v1/articles' do
  begin
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    category = params[:category]

    result = SearchService.find_all({
      page: page,
      per_page: per_page,
      category: category,
      published_only: true,
      include_deleted: false
    })

    articles_data = result[:articles].map { |a| serialize_article(a) }

    api_v1_response(articles_data, result[:meta], 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to retrieve articles", { database: e.message }, 500)
  end
end

# GET /api/v1/articles/:id - Get single article by ID
get '/api/v1/articles/:id' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      return api_v1_error('Invalid article ID', {}, 400)
    end

    article = Article.published.not_deleted[article_id]

    unless article
      return api_v1_error("Article with ID #{article_id} not found", {}, 404)
    end

    api_v1_response(serialize_article(article), {}, 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to retrieve article", { database: e.message }, 500)
  end
end

# GET /api/v1/articles/slug/:slug - Get single article by slug
get '/api/v1/articles/slug/:slug' do
  begin
    slug = params[:slug]

    article = Article.published.not_deleted.where(slug: slug).first

    unless article
      return api_v1_error("Article with slug '#{slug}' not found", {}, 404)
    end

    api_v1_response(serialize_article(article), {}, 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to retrieve article", { database: e.message }, 500)
  end
end

# GET /api/v1/search - Search articles with pagination
get '/api/v1/search' do
  begin
    query = params[:q]

    if query.nil? || query.strip.empty?
      return api_v1_error('Query parameter "q" is required and cannot be empty', {}, 400)
    end

    query = sanitize_input(query)
    if query.length > 255
      return api_v1_error('Query parameter must be less than 255 characters', {}, 400)
    end

    page = params[:page] || 1
    per_page = params[:per_page] || 20
    category = params[:category]

    service = SearchService.new(query, {
      page: page,
      per_page: per_page,
      category: category,
      published_only: true,
      include_deleted: false
    })

    result = service.search
    articles_data = result[:articles].map { |a| serialize_article(a) }

    api_v1_response(articles_data, result[:meta].merge(query: query), 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Search failed", { database: e.message }, 500)
  end
end

# POST /api/v1/articles - Create new article
post '/api/v1/articles' do
  begin
    request.body.rewind
    body = request.body.read

    if body.empty?
      return api_v1_error('Request body is required', {}, 400)
    end

    data = JSON.parse(body)

    creator = ArticleCreator.new(data)
    article = creator.create

    if article
      api_v1_response(serialize_article(article), { created: true }, 201)
    else
      api_v1_error('Validation failed', creator.errors, 422)
    end
  rescue JSON::ParserError => e
    api_v1_error('Invalid JSON in request body', { parse_error: e.message }, 400)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to create article", { database: e.message }, 500)
  end
end

# PATCH /api/v1/articles/:id/publish - Publish an article
patch '/api/v1/articles/:id/publish' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      return api_v1_error('Invalid article ID', {}, 400)
    end

    article = Article[article_id]

    unless article
      return api_v1_error("Article with ID #{article_id} not found", {}, 404)
    end

    publisher = ArticlePublisher.new(article)

    if publisher.publish
      api_v1_response(serialize_article(article.reload), { published: true }, 200)
    else
      api_v1_error('Failed to publish article', publisher.errors, 500)
    end
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to publish article", { database: e.message }, 500)
  end
end

# PATCH /api/v1/articles/:id/unpublish - Unpublish an article
patch '/api/v1/articles/:id/unpublish' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      return api_v1_error('Invalid article ID', {}, 400)
    end

    article = Article[article_id]

    unless article
      return api_v1_error("Article with ID #{article_id} not found", {}, 404)
    end

    publisher = ArticlePublisher.new(article)

    if publisher.unpublish
      api_v1_response(serialize_article(article.reload), { unpublished: true }, 200)
    else
      api_v1_error('Failed to unpublish article', publisher.errors, 500)
    end
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to unpublish article", { database: e.message }, 500)
  end
end

# DELETE /api/v1/articles/:id - Soft delete an article
delete '/api/v1/articles/:id' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      return api_v1_error('Invalid article ID', {}, 400)
    end

    article = Article.not_deleted[article_id]

    unless article
      return api_v1_error("Article with ID #{article_id} not found", {}, 404)
    end

    article.soft_delete

    api_v1_response({ deleted: true, id: article_id }, {}, 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to delete article", { database: e.message }, 500)
  end
end

# GET /api/v1/categories - List all categories
get '/api/v1/categories' do
  begin
    categories = Article.published.not_deleted
                        .select(:category)
                        .distinct
                        .where(Sequel.~(category: nil))
                        .where(Sequel.~(category: ''))
                        .all
                        .map(&:category)
                        .sort

    api_v1_response(categories, { total: categories.length }, 200)
  rescue Sequel::DatabaseError => e
    api_v1_error("Failed to retrieve categories", { database: e.message }, 500)
  end
end

# RSS Feed endpoint
get '/feed.xml' do
  content_type 'application/rss+xml'

  begin
    articles = Article.where(is_published: true).order(Sequel.desc(:published_at)).limit(20).all

    builder = Builder::XmlMarkup.new(indent: 2)
    builder.instruct! :xml, version: '1.0'

    builder.rss version: '2.0' do
      builder.channel do
        builder.title 'Knowledge Base Articles'
        builder.link 'http://localhost:4567'
        builder.description 'Latest articles from the knowledge base'
        builder.language 'en-us'

        articles.each do |article|
          builder.item do
            builder.title article.title
            builder.link "http://localhost:4567/api/articles/#{article.id}"
            builder.description article.content
            builder.author article.author if article.author
            builder.category article.category if article.category
            builder.pubDate article.published_at.rfc822 if article.published_at
            builder.guid "http://localhost:4567/api/articles/#{article.id}", isPermaLink: true
          end
        end
      end
    end
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Failed to generate RSS feed: #{e.message}")
  rescue StandardError => e
    raise KnowledgeBaseError.new("Failed to generate RSS feed: #{e.message}")
  end
end

# Web form to create new articles
get '/new' do
  @title = 'New Article - Knowledge Base'
  haml :new
end

# Handle article creation
post '/articles' do
  begin
    creator = ArticleCreator.new({
      title: params[:title],
      content: params[:content],
      author: params[:author],
      category: params[:category],
      tags: params[:tags],
      is_published: params[:is_published] == 'true'
    })

    article = creator.create

    if article
      redirect "/articles/#{article.id}"
    else
      # Show error page with validation errors
      @title = 'Error - Knowledge Base'
      @error = 'Validation failed'
      @validation_errors = creator.errors
      haml :error
    end
  rescue DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to create article: #{e.message}"
    haml :error
  end
end

# View all articles (HTML)
get '/articles' do
  begin
    @title = 'All Articles - Knowledge Base'
    @articles = Article.order(Sequel.desc(:created_at)).all
    haml :articles
  rescue Sequel::DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to load articles: #{e.message}"
    haml :error
  end
end

# View single article (HTML)
get '/articles/:id' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      raise InvalidRequestError.new('Invalid article ID')
    end

    @article = Article[article_id]

    unless @article
      @title = 'Not Found - Knowledge Base'
      @error = "Article with ID #{article_id} not found"
      status 404
      return haml :error
    end

    @title = "#{@article.title} - Knowledge Base"
    haml :show
  rescue Sequel::DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to load article: #{e.message}"
    haml :error
  rescue InvalidRequestError => e
    @title = 'Error - Knowledge Base'
    @error = e.message
    status 400
    haml :error
  end
end

# Edit article form (HTML)
get '/articles/:id/edit' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      raise InvalidRequestError.new('Invalid article ID')
    end

    @article = Article[article_id]

    unless @article
      @title = 'Not Found - Knowledge Base'
      @error = "Article with ID #{article_id} not found"
      status 404
      return haml :error
    end

    @title = "Edit #{@article.title} - Knowledge Base"
    haml :edit
  rescue Sequel::DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to load article: #{e.message}"
    haml :error
  rescue InvalidRequestError => e
    @title = 'Error - Knowledge Base'
    @error = e.message
    status 400
    haml :error
  end
end

# Update article (HTML form handler)
post '/articles/:id' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      raise InvalidRequestError.new('Invalid article ID')
    end

    @article = Article[article_id]

    unless @article
      @title = 'Not Found - Knowledge Base'
      @error = "Article with ID #{article_id} not found"
      status 404
      return haml :error
    end

    # Sanitize and validate input
    title = sanitize_input(params[:title])
    content = sanitize_input(params[:content])
    author = sanitize_input(params[:author])
    category = sanitize_input(params[:category])
    tags = sanitize_input(params[:tags])
    is_published = params[:is_published] == 'true'

    # Update article
    @article.update(
      title: title,
      content: content,
      author: author,
      category: category,
      tags: tags,
      is_published: is_published,
      published_at: is_published ? (@article.published_at || Time.now) : nil,
      updated_at: Time.now
    )

    redirect "/articles/#{@article.id}"
  rescue ValidationError => e
    @title = 'Error - Knowledge Base'
    @error = e.message
    @validation_errors = e.validation_errors
    haml :error
  rescue Sequel::DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to update article: #{e.message}"
    haml :error
  rescue InvalidRequestError => e
    @title = 'Error - Knowledge Base'
    @error = e.message
    status 400
    haml :error
  end
end

# Delete article (HTML form handler - soft delete)
post '/articles/:id/delete' do
  begin
    article_id = params[:id].to_i
    if article_id <= 0
      raise InvalidRequestError.new('Invalid article ID')
    end

    article = Article[article_id]

    unless article
      @title = 'Not Found - Knowledge Base'
      @error = "Article with ID #{article_id} not found"
      status 404
      return haml :error
    end

    # Soft delete the article
    article.soft_delete

    redirect '/articles'
  rescue Sequel::DatabaseError => e
    @title = 'Error - Knowledge Base'
    @error = "Failed to delete article: #{e.message}"
    haml :error
  rescue InvalidRequestError => e
    @title = 'Error - Knowledge Base'
    @error = e.message
    status 400
    haml :error
  end
end

# Root endpoint
get '/' do
  content_type :json
  json({
    name: 'Knowledge Base MCP Server',
    version: '2.0.0',
    api_version: 'v1',
    endpoints: {
      web: {
        new_article: 'GET /new',
        all_articles: 'GET /articles',
        view_article: 'GET /articles/:id',
        edit_article: 'GET /articles/:id/edit',
        update_article: 'POST /articles/:id',
        delete_article: 'POST /articles/:id/delete'
      },
      mcp: 'POST /mcp',
      api: {
        articles: 'GET /api/v1/articles (supports ?page=N&per_page=N&category=X)',
        article_by_id: 'GET /api/v1/articles/:id',
        article_by_slug: 'GET /api/v1/articles/slug/:slug',
        search: 'GET /api/v1/search?q=query (supports ?page=N&per_page=N&category=X)',
        create_article: 'POST /api/v1/articles',
        publish_article: 'PATCH /api/v1/articles/:id/publish',
        unpublish_article: 'PATCH /api/v1/articles/:id/unpublish',
        delete_article: 'DELETE /api/v1/articles/:id',
        categories: 'GET /api/v1/categories'
      },
      feed: 'GET /feed.xml',
      docs: '/docs/api.md and /docs/mcp-protocol.md'
    }
  })
end
