# Sample PRD: User Management

## Overview
Create a basic User model with authentication support.

## Requirements

### User Model
- Fields: name (required), email (required, unique), password_digest
- Validations: email format, name presence
- Has secure password via bcrypt

### Authentication
- User can authenticate with email and password
- Password must be at least 8 characters

## Acceptance Criteria
- User model with validations
- Factory for testing
- Authentication works correctly
