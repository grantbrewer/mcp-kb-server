require 'sinatra'
require 'sinatra/json'
require 'json'
require 'builder'
require 'haml'
require_relative 'lib/models'
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

  MCPHandler.handle(body)
end

# JSON API endpoints
get '/api/articles' do
  content_type :json

  begin
    articles = Article.where(is_published: true).all

    json articles.map { |a|
      {
        id: a.id,
        title: a.title,
        slug: a.slug,
        content: a.content,
        author: a.author,
        category: a.category,
        tags: a.tag_list,
        published_at: a.published_at,
        created_at: a.created_at,
        updated_at: a.updated_at
      }
    }
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Failed to retrieve articles: #{e.message}")
  end
end

get '/api/articles/:id' do
  content_type :json

  begin
    # Validate ID parameter
    article_id = params[:id].to_i
    if article_id <= 0
      raise InvalidRequestError.new('Invalid article ID')
    end

    article = Article[article_id]

    unless article
      raise ArticleNotFoundError.new("Article with ID #{article_id} not found")
    end

    unless article.is_published
      raise ArticleNotFoundError.new("Article with ID #{article_id} not found or not published")
    end

    json({
      id: article.id,
      title: article.title,
      slug: article.slug,
      content: article.content,
      author: article.author,
      category: article.category,
      tags: article.tag_list,
      published_at: article.published_at,
      created_at: article.created_at,
      updated_at: article.updated_at
    })
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Failed to retrieve article: #{e.message}")
  end
end

get '/api/search' do
  content_type :json

  begin
    query = params[:q]

    # Validate query parameter
    if query.nil? || query.strip.empty?
      raise InvalidRequestError.new('Query parameter "q" is required and cannot be empty')
    end

    # Sanitize and validate query length
    query = sanitize_input(query)
    if query.length > 255
      raise InvalidRequestError.new('Query parameter must be less than 255 characters')
    end

    articles = Article.search(query).where(is_published: true).all

    json articles.map { |a|
      {
        id: a.id,
        title: a.title,
        slug: a.slug,
        content: a.content,
        author: a.author,
        category: a.category,
        tags: a.tag_list,
        published_at: a.published_at
      }
    }
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Search failed: #{e.message}")
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
    # Sanitize and validate input
    title = sanitize_input(params[:title])
    content = sanitize_input(params[:content])
    author = sanitize_input(params[:author])
    category = sanitize_input(params[:category])
    tags = sanitize_input(params[:tags])
    is_published = params[:is_published] == 'true'

    # Validate required fields
    if title.nil? || title.empty?
      raise ValidationError.new('Validation failed', validation_errors: { title: ['cannot be empty'] })
    end

    if content.nil? || content.empty?
      raise ValidationError.new('Validation failed', validation_errors: { content: ['cannot be empty'] })
    end

    # Validate title length
    if title.length < 3
      raise ValidationError.new('Validation failed', validation_errors: { title: ['must be at least 3 characters'] })
    end

    if title.length > 255
      raise ValidationError.new('Validation failed', validation_errors: { title: ['must be less than 255 characters'] })
    end

    # Validate content length
    if content.length < 10
      raise ValidationError.new('Validation failed', validation_errors: { content: ['must be at least 10 characters'] })
    end

    slug = generate_slug(title)
    now = Time.now

    # Check for duplicate slug
    existing_article = Article.where(slug: slug).first
    if existing_article
      raise ValidationError.new('Validation failed', validation_errors: { slug: ['must be unique (an article with this title already exists)'] })
    end

    article = Article.create(
      title: title,
      slug: slug,
      content: content,
      author: author,
      category: category,
      tags: tags,
      published_at: is_published ? now : nil,
      created_at: now,
      updated_at: now,
      is_published: is_published
    )

    redirect "/articles/#{article.id}"
  rescue ValidationError => e
    # For web interface, show error page
    @title = 'Error - Knowledge Base'
    @error = e.message
    @validation_errors = e.validation_errors
    haml :error
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Failed to create article: #{e.message}")
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

# Root endpoint
get '/' do
  content_type :json
  json({
    name: 'Knowledge Base MCP Server',
    version: '1.0.0',
    endpoints: {
      web: {
        new_article: 'GET /new',
        all_articles: 'GET /articles',
        view_article: 'GET /articles/:id'
      },
      mcp: 'POST /mcp',
      api: {
        articles: 'GET /api/articles',
        article: 'GET /api/articles/:id',
        search: 'GET /api/search?q=query'
      },
      feed: 'GET /feed.xml'
    }
  })
end
