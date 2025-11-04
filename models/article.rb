require_relative '../config/database'
require_relative '../lib/errors'

class Article < Sequel::Model
  # Validations
  plugin :validation_helpers

  def validate
    super
    validates_presence [:title, :content], message: 'cannot be empty'
    validates_min_length 3, :title, message: 'must be at least 3 characters'
    validates_max_length 255, :title, message: 'must be less than 255 characters'
    validates_min_length 10, :content, message: 'must be at least 10 characters'
    validates_unique :slug, message: 'must be unique (an article with this slug already exists)'

    # Validate slug format
    if slug && !slug.match?(/\A[a-z0-9-]+\z/)
      errors.add(:slug, 'must contain only lowercase letters, numbers, and hyphens')
    end

    # Validate published_at if is_published is true
    if is_published && !published_at
      errors.add(:published_at, 'must be set when article is published')
    end
  end

  # Scopes (dataset methods)
  dataset_module do
    # Return only published articles
    def published
      where(is_published: true)
    end

    # Return only draft articles (unpublished)
    def drafts
      where(is_published: false)
    end

    # Return only non-deleted articles (soft delete filter)
    def not_deleted
      where(deleted_at: nil)
    end

    # Return recent articles ordered by published_at
    def recent
      order(Sequel.desc(:published_at))
    end

    # Return articles by category
    def by_category(category)
      where(category: category)
    end

    # Paginate results
    def paginate(page: 1, per_page: 20)
      page = [page.to_i, 1].max  # Ensure page is at least 1
      per_page = [per_page.to_i, 1].max  # Ensure per_page is at least 1
      per_page = [per_page, 100].min  # Cap at 100 items per page

      limit(per_page).offset((page - 1) * per_page)
    end

    # Get pagination metadata
    def pagination_meta(page: 1, per_page: 20)
      page = [page.to_i, 1].max
      per_page = [per_page.to_i, 1].max
      per_page = [per_page, 100].min

      total = count
      total_pages = (total.to_f / per_page).ceil

      {
        total: total,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    end
  end

  # Full-text search using FTS5
  def self.search(query)
    # Sanitize query for FTS5
    sanitized_query = query.gsub(/[^a-zA-Z0-9\s]/, '')

    return none if sanitized_query.empty?

    # Use FTS5 virtual table for search
    fts_results = DB[:articles_fts].where(
      Sequel.lit("articles_fts MATCH ?", sanitized_query)
    ).select(:rowid).all.map { |r| r[:rowid] }

    where(id: fts_results)
  end

  def tag_list
    tags ? tags.split(',').map(&:strip) : []
  end

  # Soft delete methods
  def soft_delete
    update(deleted_at: Time.now)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    !deleted_at.nil?
  end

  # Override save to raise ValidationError
  def save(*args)
    raise ValidationError.new('Validation failed', validation_errors: errors) unless valid?
    super
  rescue Sequel::ValidationFailed => e
    raise ValidationError.new('Validation failed', validation_errors: errors)
  rescue Sequel::UniqueConstraintViolation => e
    raise ValidationError.new('Duplicate entry', validation_errors: { slug: ['must be unique'] })
  rescue Sequel::DatabaseError => e
    raise DatabaseError.new("Database operation failed: #{e.message}")
  end
end
