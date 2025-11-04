# Helper methods for the Sinatra application

module Helpers
  # Generate URL-friendly slug from title
  # Converts to lowercase, removes special characters, replaces spaces with hyphens
  def generate_slug(title)
    title.downcase.strip.gsub(/[^\w\s-]/, '').gsub(/\s+/, '-')
  end

  # Sanitize user input to prevent XSS attacks
  # Removes HTML tags and trims whitespace
  def sanitize_input(input)
    return nil if input.nil?
    # Remove any HTML tags and trim whitespace
    input.to_s.gsub(/<[^>]*>/, '').strip
  end
end
