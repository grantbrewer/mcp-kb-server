Sequel.migration do
  change do
    alter_table(:articles) do
      add_index :published_at
      add_index :is_published
      add_index :category
      add_index :deleted_at
      add_index [:is_published, :published_at]
    end
  end
end
