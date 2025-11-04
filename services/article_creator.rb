require_relative '../models/article'
require_relative '../lib/helpers'

class ArticleCreator
  include Helpers

  attr_reader :errors

  def initialize(params)
    @params = params
    @errors = {}
  end

  def create
    # Sanitize inputs
    title = sanitize_input(@params[:title] || @params['title'])
    content = sanitize_input(@params[:content] || @params['content'])
    author = sanitize_input(@params[:author] || @params['author'])
    category = sanitize_input(@params[:category] || @params['category'])
    tags = sanitize_input(@params[:tags] || @params['tags'])
    is_published = @params[:is_published] == true || @params[:is_published] == 'true' ||
                   @params['is_published'] == true || @params['is_published'] == 'true'

    # Validate title before generating slug
    if title.nil? || title.empty?
      @errors = { title: ['cannot be empty'] }
      return nil
    end

    # Generate slug from title
    slug = generate_slug(title)
    now = Time.now

    # Create article
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

    article
  rescue ValidationError => e
    @errors = e.validation_errors
    nil
  rescue DatabaseError => e
    @errors = { base: [e.message] }
    nil
  end

  def valid?
    @errors.empty?
  end
end
