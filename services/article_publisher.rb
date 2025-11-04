require_relative '../models/article'

class ArticlePublisher
  attr_reader :article, :errors

  def initialize(article)
    @article = article
    @errors = {}
  end

  def publish
    return false if @article.nil?
    return true if @article.is_published  # Already published

    @article.update(
      is_published: true,
      published_at: Time.now
    )

    true
  rescue Sequel::DatabaseError => e
    @errors = { base: ["Failed to publish article: #{e.message}"] }
    false
  end

  def unpublish
    return false if @article.nil?
    return true unless @article.is_published  # Already unpublished

    @article.update(
      is_published: false,
      published_at: nil
    )

    true
  rescue Sequel::DatabaseError => e
    @errors = { base: ["Failed to unpublish article: #{e.message}"] }
    false
  end

  def toggle
    if @article.is_published
      unpublish
    else
      publish
    end
  end
end
