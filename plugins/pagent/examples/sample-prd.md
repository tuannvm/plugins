# Product Requirements Document: Task Management API

## Overview

Build a REST API for a simple task management application. The API should allow users to create, read, update, and delete tasks organized into projects.

## Goals

1. Provide a simple, intuitive API for task management
2. Support multiple users with authentication
3. Enable organization of tasks into projects
4. Allow filtering and sorting of tasks

## User Stories

### Authentication
- As a user, I want to register with email/password
- As a user, I want to login and receive an access token
- As a user, I want to logout and invalidate my token

### Projects
- As a user, I want to create projects with name and description
- As a user, I want to list my projects
- As a user, I want to update project details
- As a user, I want to delete a project and all its tasks

### Tasks
- As a user, I want to create tasks within a project
- As a user, I want to set task title, description, status, priority, due date
- As a user, I want to list tasks with filters (status, priority, due date)
- As a user, I want to update task details
- As a user, I want to mark tasks as complete
- As a user, I want to delete tasks

## Data Models

### User
- id (UUID)
- email (unique)
- password_hash
- created_at
- updated_at

### Project
- id (UUID)
- user_id (foreign key)
- name
- description
- created_at
- updated_at

### Task
- id (UUID)
- project_id (foreign key)
- title
- description
- status (todo, in_progress, done)
- priority (low, medium, high)
- due_date (optional)
- created_at
- updated_at

## API Endpoints

### Authentication
- POST /api/auth/register
- POST /api/auth/login
- POST /api/auth/logout

### Projects
- GET /api/projects
- POST /api/projects
- GET /api/projects/:id
- PUT /api/projects/:id
- DELETE /api/projects/:id

### Tasks
- GET /api/projects/:id/tasks
- POST /api/projects/:id/tasks
- GET /api/tasks/:id
- PUT /api/tasks/:id
- DELETE /api/tasks/:id

## Non-Functional Requirements

- Response time < 200ms for 95th percentile
- Support 1000 concurrent users
- 99.9% uptime
- Data encrypted at rest and in transit

## Technical Preferences

- Language: Go or TypeScript
- Database: PostgreSQL
- Authentication: JWT tokens
- API Documentation: OpenAPI 3.0

## Timeline

Phase 1: Core CRUD operations (MVP)
Phase 2: Authentication and authorization
Phase 3: Filtering and sorting
Phase 4: Performance optimization
