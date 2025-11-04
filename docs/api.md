# Knowledge Base API Documentation

Version: 2.0.0
API Version: v1

## Overview

The Knowledge Base API provides RESTful endpoints for managing and querying articles. All API v1 endpoints follow a consistent response format with proper HTTP status codes.

## Base URL

```
http://localhost:4567
```

## Response Format

All API v1 endpoints return JSON responses with the following structure:

### Success Response
```json
{
  "data": { /* response data */ },
  "meta": { /* metadata like pagination info */ }
}
```

### Error Response
```json
{
  "errors": {
    "message": "Error description",
    "details": { /* detailed error information */ }
  }
}
```

## HTTP Status Codes

- `200 OK` - Successful GET/PATCH/DELETE request
- `201 Created` - Successful POST request (resource created)
- `400 Bad Request` - Invalid request parameters
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation failed
- `500 Internal Server Error` - Server error

---

## Endpoints

### 1. List All Articles

Get a paginated list of published articles.

**Endpoint:** `GET /api/v1/articles`

**Query Parameters:**
- `page` (integer, optional) - Page number (default: 1)
- `per_page` (integer, optional) - Items per page (default: 20, max: 100)
- `category` (string, optional) - Filter by category

**Example Request:**
```bash
curl http://localhost:4567/api/v1/articles?page=1&per_page=10
```

**Example Response:**
```json
{
  "data": [
    {
      "id": 1,
      "title": "Getting Started",
      "slug": "getting-started",
      "content": "Article content...",
      "author": "John Doe",
      "category": "Tutorial",
      "tags": ["guide", "beginner"],
      "published_at": "2024-11-04T12:00:00Z",
      "created_at": "2024-11-04T11:00:00Z",
      "updated_at": "2024-11-04T11:00:00Z",
      "is_published": true
    }
  ],
  "meta": {
    "total": 100,
    "page": 1,
    "per_page": 10,
    "total_pages": 10
  }
}
```

---

### 2. Get Article by ID

Get a single article by its numeric ID.

**Endpoint:** `GET /api/v1/articles/:id`

**Path Parameters:**
- `id` (integer, required) - Article ID

**Example Request:**
```bash
curl http://localhost:4567/api/v1/articles/1
```

**Example Response:**
```json
{
  "data": {
    "id": 1,
    "title": "Getting Started",
    "slug": "getting-started",
    "content": "Article content...",
    "author": "John Doe",
    "category": "Tutorial",
    "tags": ["guide", "beginner"],
    "published_at": "2024-11-04T12:00:00Z",
    "created_at": "2024-11-04T11:00:00Z",
    "updated_at": "2024-11-04T11:00:00Z",
    "is_published": true
  },
  "meta": {}
}
```

---

### 3. Get Article by Slug

Get a single article by its URL-friendly slug.

**Endpoint:** `GET /api/v1/articles/slug/:slug`

**Path Parameters:**
- `slug` (string, required) - Article slug

**Example Request:**
```bash
curl http://localhost:4567/api/v1/articles/slug/getting-started
```

**Example Response:**
```json
{
  "data": {
    "id": 1,
    "title": "Getting Started",
    "slug": "getting-started",
    "content": "Article content...",
    "author": "John Doe",
    "category": "Tutorial",
    "tags": ["guide", "beginner"],
    "published_at": "2024-11-04T12:00:00Z",
    "created_at": "2024-11-04T11:00:00Z",
    "updated_at": "2024-11-04T11:00:00Z",
    "is_published": true
  },
  "meta": {}
}
```

---

### 4. Search Articles

Search articles using full-text search (powered by SQLite FTS5).

**Endpoint:** `GET /api/v1/search`

**Query Parameters:**
- `q` (string, required) - Search query
- `page` (integer, optional) - Page number (default: 1)
- `per_page` (integer, optional) - Items per page (default: 20, max: 100)
- `category` (string, optional) - Filter by category

**Example Request:**
```bash
curl "http://localhost:4567/api/v1/search?q=tutorial&category=Guide&page=1"
```

**Example Response:**
```json
{
  "data": [
    {
      "id": 1,
      "title": "Getting Started Tutorial",
      "slug": "getting-started-tutorial",
      "content": "This is a tutorial article...",
      "author": "John Doe",
      "category": "Guide",
      "tags": ["tutorial", "beginner"],
      "published_at": "2024-11-04T12:00:00Z",
      "created_at": "2024-11-04T11:00:00Z",
      "updated_at": "2024-11-04T11:00:00Z",
      "is_published": true
    }
  ],
  "meta": {
    "total": 5,
    "page": 1,
    "per_page": 20,
    "total_pages": 1,
    "query": "tutorial"
  }
}
```

---

### 5. Create Article

Create a new article.

**Endpoint:** `POST /api/v1/articles`

**Request Body:**
```json
{
  "title": "My New Article",
  "content": "This is the article content. It must be at least 10 characters.",
  "author": "Jane Smith",
  "category": "Tutorial",
  "tags": "guide,beginner,help",
  "is_published": true
}
```

**Field Requirements:**
- `title` (string, required) - 3-255 characters
- `content` (string, required) - Minimum 10 characters
- `author` (string, optional)
- `category` (string, optional)
- `tags` (string, optional) - Comma-separated list
- `is_published` (boolean, optional) - Default: false

**Example Request:**
```bash
curl -X POST http://localhost:4567/api/v1/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My New Article",
    "content": "This is the article content.",
    "author": "Jane Smith",
    "is_published": true
  }'
```

**Example Success Response (201 Created):**
```json
{
  "data": {
    "id": 2,
    "title": "My New Article",
    "slug": "my-new-article",
    "content": "This is the article content.",
    "author": "Jane Smith",
    "category": null,
    "tags": [],
    "published_at": "2024-11-04T13:00:00Z",
    "created_at": "2024-11-04T13:00:00Z",
    "updated_at": "2024-11-04T13:00:00Z",
    "is_published": true
  },
  "meta": {
    "created": true
  }
}
```

**Example Validation Error Response (422 Unprocessable Entity):**
```json
{
  "errors": {
    "message": "Validation failed",
    "details": {
      "title": ["cannot be empty"],
      "content": ["must be at least 10 characters"]
    }
  }
}
```

---

### 6. Publish Article

Publish an unpublished article (sets `is_published=true` and `published_at=now`).

**Endpoint:** `PATCH /api/v1/articles/:id/publish`

**Path Parameters:**
- `id` (integer, required) - Article ID

**Example Request:**
```bash
curl -X PATCH http://localhost:4567/api/v1/articles/2/publish
```

**Example Response:**
```json
{
  "data": {
    "id": 2,
    "title": "My New Article",
    "slug": "my-new-article",
    "content": "This is the article content.",
    "author": "Jane Smith",
    "category": null,
    "tags": [],
    "published_at": "2024-11-04T14:00:00Z",
    "created_at": "2024-11-04T13:00:00Z",
    "updated_at": "2024-11-04T13:00:00Z",
    "is_published": true
  },
  "meta": {
    "published": true
  }
}
```

---

### 7. Unpublish Article

Unpublish a published article (sets `is_published=false` and `published_at=null`).

**Endpoint:** `PATCH /api/v1/articles/:id/unpublish`

**Path Parameters:**
- `id` (integer, required) - Article ID

**Example Request:**
```bash
curl -X PATCH http://localhost:4567/api/v1/articles/2/unpublish
```

**Example Response:**
```json
{
  "data": {
    "id": 2,
    "title": "My New Article",
    "slug": "my-new-article",
    "content": "This is the article content.",
    "author": "Jane Smith",
    "category": null,
    "tags": [],
    "published_at": null,
    "created_at": "2024-11-04T13:00:00Z",
    "updated_at": "2024-11-04T13:00:00Z",
    "is_published": false
  },
  "meta": {
    "unpublished": true
  }
}
```

---

### 8. Delete Article (Soft Delete)

Soft delete an article (sets `deleted_at` timestamp, article won't appear in queries).

**Endpoint:** `DELETE /api/v1/articles/:id`

**Path Parameters:**
- `id` (integer, required) - Article ID

**Example Request:**
```bash
curl -X DELETE http://localhost:4567/api/v1/articles/2
```

**Example Response:**
```json
{
  "data": {
    "deleted": true,
    "id": 2
  },
  "meta": {}
}
```

**Note:** Soft deleted articles are not permanently removed from the database. They can be restored by updating the `deleted_at` column to `NULL` directly in the database.

---

### 9. List Categories

Get a list of all unique categories from published articles.

**Endpoint:** `GET /api/v1/categories`

**Example Request:**
```bash
curl http://localhost:4567/api/v1/categories
```

**Example Response:**
```json
{
  "data": [
    "Guide",
    "Reference",
    "Tutorial"
  ],
  "meta": {
    "total": 3
  }
}
```

---

## Pagination

All list endpoints support pagination with the following parameters:

- `page` - Page number (default: 1, minimum: 1)
- `per_page` - Items per page (default: 20, minimum: 1, maximum: 100)

Pagination metadata is returned in the `meta` field:

```json
{
  "meta": {
    "total": 100,
    "page": 2,
    "per_page": 20,
    "total_pages": 5
  }
}
```

---

## Full-Text Search

The search endpoint uses SQLite FTS5 (Full-Text Search) for fast, relevance-based searching. Search queries match against article titles and content.

**Search Features:**
- Searches both title and content fields
- Case-insensitive matching
- Supports multiple word queries
- Results ordered by published date (newest first)

---

## Error Handling

All errors follow the consistent format:

```json
{
  "errors": {
    "message": "Human-readable error message",
    "details": {
      "field_name": ["error description"]
    }
  }
}
```

Common error scenarios:

1. **Invalid ID** (400 Bad Request)
2. **Resource Not Found** (404 Not Found)
3. **Validation Failed** (422 Unprocessable Entity)
4. **Database Error** (500 Internal Server Error)

---

## Examples

### Create and Publish an Article

```bash
# 1. Create article as draft
curl -X POST http://localhost:4567/api/v1/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "How to Use the API",
    "content": "This guide explains how to use our API...",
    "author": "API Team",
    "category": "Documentation",
    "tags": "api,guide,documentation",
    "is_published": false
  }'

# Response includes id: 42

# 2. Publish the article
curl -X PATCH http://localhost:4567/api/v1/articles/42/publish
```

### Search and Filter

```bash
# Search for "docker" in Tutorial category
curl "http://localhost:4567/api/v1/search?q=docker&category=Tutorial&page=1&per_page=10"
```

### Pagination Through Results

```bash
# Get page 1
curl "http://localhost:4567/api/v1/articles?page=1&per_page=20"

# Get page 2
curl "http://localhost:4567/api/v1/articles?page=2&per_page=20"
```

---

## Rate Limiting

Currently, there are no rate limits enforced. This may change in future versions.

---

## Support

For issues or questions, please refer to the main README.md or open an issue on the project repository.
