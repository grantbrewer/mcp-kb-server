Sequel.migration do
  up do
    # Create FTS5 virtual table for full-text search
    run <<-SQL
      CREATE VIRTUAL TABLE articles_fts USING fts5(
        title,
        content,
        content=articles,
        content_rowid=id
      );
    SQL

    # Create triggers to keep FTS index in sync with articles table
    run <<-SQL
      CREATE TRIGGER articles_fts_insert AFTER INSERT ON articles BEGIN
        INSERT INTO articles_fts(rowid, title, content)
        VALUES (new.id, new.title, new.content);
      END;
    SQL

    run <<-SQL
      CREATE TRIGGER articles_fts_update AFTER UPDATE ON articles BEGIN
        UPDATE articles_fts
        SET title = new.title, content = new.content
        WHERE rowid = old.id;
      END;
    SQL

    run <<-SQL
      CREATE TRIGGER articles_fts_delete AFTER DELETE ON articles BEGIN
        DELETE FROM articles_fts WHERE rowid = old.id;
      END;
    SQL

    # Populate FTS table with existing data
    run <<-SQL
      INSERT INTO articles_fts(rowid, title, content)
      SELECT id, title, content FROM articles;
    SQL
  end

  down do
    run "DROP TRIGGER IF EXISTS articles_fts_delete;"
    run "DROP TRIGGER IF EXISTS articles_fts_update;"
    run "DROP TRIGGER IF EXISTS articles_fts_insert;"
    run "DROP TABLE IF EXISTS articles_fts;"
  end
end
