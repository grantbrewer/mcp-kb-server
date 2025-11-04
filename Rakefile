require 'sequel'
require_relative 'config/database'

namespace :db do
  desc 'Run database migrations'
  task :migrate do
    Sequel.extension :migration
    Sequel::Migrator.run(DB, 'db/migrations')
    puts 'Migrations completed'
  end

  desc 'Rollback database migration'
  task :rollback do
    Sequel.extension :migration
    Sequel::Migrator.run(DB, 'db/migrations', target: 0)
    puts 'Rollback completed'
  end

  desc 'Seed database with sample data'
  task :seed do
    require_relative 'lib/models'

    Article.create(
      title: 'Getting Started with Ruby',
      slug: 'getting-started-ruby',
      content: 'Ruby is a dynamic, open source programming language with a focus on simplicity and productivity.',
      author: 'Ruby Team',
      category: 'Tutorial',
      tags: 'ruby,programming,beginner',
      published_at: Time.now,
      created_at: Time.now,
      updated_at: Time.now,
      is_published: true
    )

    Article.create(
      title: 'Understanding Sequel ORM',
      slug: 'understanding-sequel-orm',
      content: 'Sequel is a simple, flexible, and powerful SQL database toolkit for Ruby.',
      author: 'Database Admin',
      category: 'Guide',
      tags: 'sequel,orm,database',
      published_at: Time.now,
      created_at: Time.now,
      updated_at: Time.now,
      is_published: true
    )

    Article.create(
      title: 'Building REST APIs with Sinatra',
      slug: 'building-rest-apis-sinatra',
      content: 'Sinatra is a lightweight web framework perfect for building APIs and microservices.',
      author: 'Web Developer',
      category: 'Tutorial',
      tags: 'sinatra,api,web',
      published_at: Time.now,
      created_at: Time.now,
      updated_at: Time.now,
      is_published: true
    )

    puts 'Database seeded with sample articles'
  end
end
