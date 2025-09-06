# Lessons Learned - GameEight Development

## Purpose
This document captures important patterns, preferences, and project intelligence discovered during GameEight development. It serves as a learning journal that grows smarter as development progresses.

## Project Intelligence

### Development Environment Insights
*To be updated as development progresses*

**Phoenix LiveView Patterns:**
- **Card Visibility Implementation:** Successfully designed UI that shows private hand cards to each player while displaying public table cards to everyone
- **LiveView Structure:** Proper separation of mount/2, handle_params/3, render/1, and handle_event/3 functions for game interface
- **Route Integration:** Added authenticated routes for game access with proper user authentication checks
- **Template Organization:** Used helper functions for rendering different game states (dice_rolling, playing, etc.)
- **Asset Management:** Integrated custom CSS classes for cards with Phoenix component system
- **PubSub Planning:** Prepared for real-time updates by subscribing to game-specific channels in mount/2

### Database and Ecto Patterns
*To be updated during schema development*

### Testing Strategies
*To be documented as test suite develops*

## Current Session Learnings

### Card Game Implementation (Phase 1 - Data Structures)
**Session Focus:** Building foundational card game data structures for multiplayer Rummy-style game

**Key Technical Insights:**
- **File Verification:** Always verify the existence and content of files before attempting to modify them, especially when dealing with configuration or memory files.
- **Tool Selection:** Choose the correct tool for the task at hand, considering the specific requirements of each tool (e.g., `write_to_file` vs. `replace_in_file`).
- **MCP Server Verification:** Confirm MCP server availability and correct configuration before attempting to use its tools.
- **Task Planning:** Document tasks clearly in `tasks/tasks_plan.md` before starting implementation.
- **Follow Instructions Precisely:** Adhere strictly to the instructions and guidelines provided, especially regarding tool usage and mode switching.
- **Compilation Warnings Management:** Always address compilation warnings promptly to maintain clean code. Use `mix compile --warnings-as-errors` to catch issues early.
- **Ecto Schema Dependencies:** When working with Ecto schemas, ensure all necessary aliases are present (especially `Repo` for database operations).
- **Function Duplication Prevention:** When adding functions to existing modules, always check for existing implementations to avoid duplicates that cause compilation warnings.
- **Test Coverage Validation:** Use comprehensive tests (all 146 tests passing) to ensure code quality and detect regressions during refactoring.

**Elixir/Phoenix Specific:**
- **Card Module Design:** Successfully implemented 104-card deck system (2 English decks) with comprehensive validation for trios and sequences
- **Schema Relationships:** Established proper foreign key relationships between GameState and PlayerGameState using binary_id primary keys
- **JSON Field Usage:** Effectively used Ecto's JSON fields for storing card lists and game combinations in PostgreSQL
- **Helper Functions:** Created card conversion utilities (cards_to_hand/1, hand_to_cards/1) for seamless database storage and retrieval

**CSS and Styling:**
- **Card Styling System:** Developed comprehensive CSS classes for game cards with proper suit colors (red/blue decks), hover effects, and drag states
- **TailwindCSS Integration:** Successfully extended TailwindCSS with custom game-specific styles while maintaining utility-first approach
- **Responsive Design:** Implemented mobile-friendly card layouts that work across different screen sizes

**Testing Strategy:**
- **Comprehensive Coverage:** Achieved 150 passing tests covering all core functionality including Engine module
- **Edge Case Testing:** Included tests for invalid card combinations, empty hands, and boundary conditions
- **Test Organization:** Properly structured tests for each module with clear test descriptions
- **Test Fixture Usage:** Successfully used AccountsFixtures and GameFixtures for consistent test setup
- **Ecto insert_all Usage:** Learned proper field mapping for insert_all operations - requires exact schema field names and proper timestamp truncation for :utc_datetime fields
- **Room State Testing:** Developed strategies for testing game engine with various room states using direct Repo updates when needed

### Session: Memory Bank Initialization (September 6, 2025)

#### Project Structure Understanding
- **Phoenix 1.8 Structure:** Confirmed standard Phoenix app structure with LiveView integration
- **Asset Pipeline:** TailwindCSS and ESBuild properly configured in `assets/` directory
- **Development Tools:** Comprehensive mix aliases including `precommit` for quality checks

#### Technology Stack Analysis
- **HTTP Client Choice:** Req library is explicitly preferred over HTTPoison/Tesla per project guidelines
- **Icon Strategy:** Heroicons integrated directly with Phoenix `<.icon>` component
- **Styling Approach:** TailwindCSS with utility-first methodology
- **Real-time Strategy:** Phoenix LiveView chosen over separate frontend framework

#### Project Guidelines Discovery
- **Code Quality:** `mix precommit` alias enforces strict quality standards
- **Phoenix Conventions:** Strict adherence to Phoenix 1.8 patterns required
- **LiveView Best Practices:** Specific patterns for layouts, forms, and components documented

## Development Patterns

### Memory Bank System Usage
- **Documentation Hierarchy:** PRD → Technical/Architecture → Tasks → Active Context
- **File Relationships:** Clear dependencies between memory files established
- **Update Strategy:** Active context and tasks plan require frequent updates

### Project Analysis Approach
1. **Start with Core Files:** README, mix.exs, and AGENTS.md provide essential context
2. **Technology Assessment:** Dependencies in mix.exs reveal tech stack decisions
3. **Structure Analysis:** lib/ directory structure shows application organization
4. **Configuration Review:** config/ files show environment setup

## Technical Insights

### Phoenix LiveView Approach
- **Server-Side State:** Chosen for simplicity and maintainability over client-side SPA
- **Real-time Communication:** Phoenix PubSub for game state synchronization
- **Component Strategy:** Phoenix Components for reusable UI elements

### Elixir/Phoenix Best Practices Confirmed
- **Pattern Matching:** Avoid index-based list access, use `Enum.at/2`
- **Immutable Variables:** Must rebind results of block expressions
- **Form Handling:** Use `to_form/2` and `<.form>` components exclusively
- **Error Handling:** Proper tuple returns for error states

### Database Strategy
- **PostgreSQL:** Primary database choice
- **Ecto Schemas:** All fields use `:string` type even for text columns
- **Migrations:** Required for all schema changes
- **Validation:** Ecto changesets for all data validation

## User Workflow Preferences

### Development Workflow
- **Quality First:** Run `mix precommit` before any commits
- **Feature Branches:** Use Git branches for all development work
- **Test-Driven:** Implement tests alongside features
- **Documentation:** Keep Memory Bank files current

### Code Organization Preferences
- **Context-Driven:** Use Phoenix contexts for business logic organization
- **Component-Based:** Reusable LiveView components for UI
- **Convention Over Configuration:** Follow Phoenix conventions strictly

## Problem-Solving Patterns

### Analysis Strategy
1. **Context Gathering:** Always start with Memory Bank files
2. **Current State Assessment:** Check what exists before planning changes
3. **Dependency Mapping:** Understand relationships between components
4. **Risk Assessment:** Identify potential issues early

### Implementation Strategy
1. **Foundation First:** Set up core infrastructure before features
2. **Incremental Development:** Build features iteratively
3. **Test Early:** Implement tests alongside code
4. **Document Continuously:** Update Memory Bank throughout development

## Tool Usage Patterns

### Mix Tasks Utilization
- **Setup:** `mix setup` for complete environment preparation
- **Development:** `mix phx.server` for development server
- **Quality:** `mix precommit` for code quality checks
- **Database:** `mix ecto.reset` for clean database state

### Asset Management
- **Development:** Hot reloading with watchers
- **Production:** Minified and digested assets
- **Dependencies:** Node.js required for asset compilation

## Communication Patterns

### Real-time Requirements
- **WebSocket Connectivity:** Essential for LiveView functionality
- **State Synchronization:** Phoenix PubSub for multi-user coordination
- **Error Handling:** Graceful degradation for connection issues

### UI/UX Considerations
- **Mobile-First:** Responsive design with TailwindCSS
- **Accessibility:** Phoenix components include accessibility features
- **Performance:** Server-side rendering for fast initial loads

## Project-Specific Intelligence

### GameEight Specifics
- **Game Type:** Still to be determined - affects entire architecture
- **Multiplayer Focus:** Real-time multiplayer is core requirement
- **State Management:** Server-side game state for consistency
- **Scalability:** Phoenix process model supports concurrent games

### Architecture Decisions
- **Layered Structure:** Web → Business Logic → Data persistence
- **Component Communication:** Parent-child and PubSub patterns
- **Error Boundaries:** Graceful error handling at each layer

## Evolution of Understanding

### Initial Assumptions
- Standard Phoenix application structure
- Real-time requirements suggest LiveView approach
- Gaming context implies state management complexity

### Confirmed Patterns
- Phoenix 1.8 conventions are strictly followed
- LiveView is the primary UI technology
- Server-side state management is the chosen approach
- TailwindCSS provides the styling foundation

### Emerging Insights
- Memory Bank system provides excellent project continuity
- Comprehensive documentation enables effective handoffs
- Project guidelines are detailed and specific
- Quality standards are high and enforced

## Future Learning Areas

### To Explore
- Specific game mechanics and their implementation patterns
- LiveView performance optimization techniques
- Multi-user state synchronization patterns
- Testing strategies for real-time applications

### To Monitor
- Database performance with concurrent users
- LiveView process memory usage
- Real-time latency and user experience
- Asset optimization impact

### To Document
- Game-specific implementation patterns
- Performance optimization discoveries
- User interaction design patterns
- Deployment and scaling insights

## Knowledge Validation

### Verified Patterns
- Phoenix 1.8 structure and conventions ✅
- LiveView component patterns ✅
- TailwindCSS integration ✅
- Mix task configuration ✅

### Assumptions to Validate
- Database performance with game state 🔄
- Real-time performance under load 🔄
- Browser compatibility across platforms 🔄
- Asset optimization effectiveness 🔄

---

*This document will be continuously updated as development progresses. Each session should add new insights and validate or refine existing knowledge.*
