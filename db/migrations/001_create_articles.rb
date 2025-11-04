Sequel.migration do
  change do
    create_table(:articles) do
      primary_key :id
      String :title, null: false
      String :slug, unique: true, null: false
      Text :content, null: false
      String :author
      String :category
      String :tags
      DateTime :published_at
      DateTime :created_at
      DateTime :updated_at
      TrueClass :is_published, default: true
    end
  end
end
