require_relative '../config/database'
require_relative 'errors'

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

  def self.search(query)
    where(Sequel.ilike(:title, "%#{query}%") | Sequel.ilike(:content, "%#{query}%"))
  end

  def tag_list
    tags ? tags.split(',').map(&:strip) : []
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
