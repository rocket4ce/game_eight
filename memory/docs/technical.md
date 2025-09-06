# Technical Documentation - GameEight

## 1. Technology Stack

### Core Framework
* **Phoenix Framework:** v1.8.0+ - Main web framework
* **Elixir:** v1.15+ - Programming language
* **Phoenix LiveView:** v1.1.0+ - Real-time interactive UI

### Database
* **PostgreSQL:** Primary database
* **Ecto:** v3.13+ - Database wrapper and query generator

### Frontend Technologies
* **TailwindCSS:** v0.3+ - Utility-first CSS framework
* **Heroicons:** v2.2.0 - SVG icon library
* **ESBuild:** v0.10+ - JavaScript bundler
* **Phoenix HTML:** v4.1+ - HTML helpers and components

### Development Tools
* **Phoenix Live Dashboard:** v0.8.3+ - Development dashboard
* **Phoenix Live Reload:** v1.2+ - Development hot reloading
* **Mix:** Build tool and task runner

### HTTP Client
* **Req:** v0.5+ - Modern HTTP client (preferred over HTTPoison/Tesla)

### Additional Libraries
* **Jason:** v1.2+ - JSON encoding/decoding
* **Swoosh:** v1.16+ - Email composition and delivery
* **Telemetry:** Metrics and monitoring
* **Gettext:** Internationalization support
* **Bandit:** v1.5+ - HTTP server

## 2. Development Environment Setup

### Prerequisites
* Elixir 1.15+
* Erlang/OTP 26+
* PostgreSQL 12+
* Node.js 18+ (for asset compilation)

### Environment Configuration
* **Development:** Configured in `config/dev.exs`
* **Test:** Configured in `config/test.exs`
* **Production:** Configured in `config/prod.exs`
* **Runtime:** Dynamic configuration in `config/runtime.exs`

### Database Configuration
* Default database: `game_eight_dev`
* Test database: `game_eight_test`
* Connection managed via Ecto and configured per environment

## 3. Project Structure

### Main Modules
* **GameEight:** Main application module
* **GameEightWeb:** Web-related modules and components
* **GameEight.Application:** OTP application behavior
* **GameEight.Repo:** Database repository interface

### Web Layer Structure
```
lib/game_eight_web/
├── components/          # Reusable LiveView components
├── controllers/         # HTTP controllers
├── endpoint.ex         # Phoenix endpoint configuration
├── gettext.ex          # Internationalization setup
├── router.ex           # URL routing configuration
└── telemetry.ex        # Telemetry and monitoring
```

### Asset Management
```
assets/
├── css/
│   └── app.css         # Main stylesheet
├── js/
│   └── app.js          # Main JavaScript entry point
└── vendor/             # Third-party assets
    ├── daisyui.js
    ├── heroicons.js
    └── topbar.js
```

## 4. Build and Development Workflow

### Available Mix Tasks
* `mix setup` - Complete project setup (deps, db, assets)
* `mix phx.server` - Start development server
* `mix test` - Run test suite
* `mix precommit` - Run quality checks (compile, format, test)

### Asset Pipeline
* **Development:** Hot reloading with esbuild and tailwind watchers
* **Production:** Minified and digested assets
* **Build Process:** Automated via Mix aliases

### Code Quality Standards
* **Compiler Warnings:** Treated as errors in CI
* **Code Formatting:** Enforced via `mix format`
* **Dependency Management:** Automated unused dependency detection
* **Testing:** Required for all features

## 5. Phoenix Framework Specifics

### Phoenix v1.8 Features Used
* **Phoenix Components:** Functional component system
* **LiveView:** Real-time server-rendered interfaces
* **Layouts Module:** Centralized layout management
* **Core Components:** Built-in UI component library

### Routing Patterns
* **Browser Pipeline:** Standard web requests with CSRF protection
* **API Pipeline:** JSON API endpoints (when needed)
* **LiveView Routes:** Real-time interactive pages

### Security Measures
* **CSRF Protection:** Enabled by default
* **Secure Headers:** Configured in browser pipeline
* **Content Security Policy:** Standard Phoenix security setup

## 6. Database and Data Management

### Ecto Configuration
* **Primary Repo:** `GameEight.Repo`
* **Migration Path:** `priv/repo/migrations/`
* **Seeds:** `priv/repo/seeds.exs`

### Database Tasks
* `mix ecto.setup` - Create and migrate database
* `mix ecto.reset` - Drop and recreate database
* `mix ecto.migrate` - Run pending migrations

## 7. Testing Strategy

### Test Environment
* **Test Database:** Automatically created and managed
* **Test Helpers:** Located in `test/support/`
* **Test Configuration:** Isolated test environment

### Testing Tools
* **ExUnit:** Core testing framework
* **Phoenix.LiveViewTest:** LiveView testing utilities
* **LazyHTML:** HTML assertion library

## 8. Performance Considerations

### Elixir/Phoenix Optimizations
* **OTP Design:** Leverages Actor model for concurrency
* **LiveView Processes:** Efficient server-side state management
* **PubSub:** Built-in publish-subscribe for real-time features

### Asset Optimization
* **CSS Purging:** TailwindCSS removes unused styles
* **JavaScript Bundling:** ESBuild optimizes client-side code
* **Static Asset Caching:** Phoenix digest pipeline

## 9. Development Best Practices

### Code Organization
* Follow Phoenix conventions for file structure
* Use appropriate contexts for business logic
* Implement proper error handling patterns

### LiveView Guidelines
* Server-side state management
* Efficient event handling
* Proper component lifecycle management

### Database Best Practices
* Use Ecto changesets for data validation
* Implement proper database constraints
* Optimize queries and preload associations

## 10. Deployment Considerations

### Production Requirements
* Elixir release building
* Database migrations
* Asset compilation and optimization
* Environment variable configuration

### Monitoring and Observability
* Telemetry metrics collection
* Phoenix LiveDashboard for development insights
* Error tracking and logging capabilities
