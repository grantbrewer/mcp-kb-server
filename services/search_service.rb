require_relative '../models/article'

class SearchService
  attr_reader :query, :options

  def initialize(query, options = {})
    @query = query
    @options = {
      page: options[:page] || 1,
      per_page: options[:per_page] || 20,
      category: options[:category],
      published_only: options[:published_only].nil? ? true : options[:published_only],
      include_deleted: options[:include_deleted] || false
    }
  end

  def search
    results = Article.search(@query)

    # Apply filters
    results = results.published if @options[:published_only]
    results = results.not_deleted unless @options[:include_deleted]
    results = results.by_category(@options[:category]) if @options[:category]

    # Order by relevance (for now, just use published_at desc)
    results = results.order(Sequel.desc(:published_at))

    # Return paginated results with metadata
    {
      articles: results.paginate(page: @options[:page], per_page: @options[:per_page]).all,
      meta: results.pagination_meta(page: @options[:page], per_page: @options[:per_page])
    }
  end

  def self.find_all(options = {})
    results = Article.dataset

    # Apply filters
    results = results.published if options[:published_only]
    results = results.not_deleted unless options[:include_deleted]
    results = results.by_category(options[:category]) if options[:category]

    # Order
    results = results.recent

    page = options[:page] || 1
    per_page = options[:per_page] || 20

    {
      articles: results.paginate(page: page, per_page: per_page).all,
      meta: results.pagination_meta(page: page, per_page: per_page)
    }
  end
end
