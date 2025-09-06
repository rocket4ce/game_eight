# Error Documentation - GameEight

## Purpose
This file documents errors, issues, and their resolutions encountered during GameEight development. This serves as a reference to avoid repeating mistakes and to build institutional knowledge.

## Current Project Status
**Last Updated:** September 6, 2025
**Project Phase:** Initial Setup - Memory Bank Initialization
**Known Issues:** None at this time (project just started)

## Error Categories

### 1. Environment Setup Errors
*No errors documented yet - environment verification pending*

### 2. Database Errors
*No errors documented yet - database setup verification pending*

### 3. Phoenix/LiveView Errors

#### Error: RuntimeError - not implemented on LiveView Streams with Enum.empty?
- **Date:** September 6, 2025
- **Context:** Loading the `/rooms` page which displays user's active game rooms
- **Error Message:** 
  ```
  ** (RuntimeError) not implemented
      (phoenix_live_view 1.1.11) lib/phoenix_live_view/live_stream.ex:135: Enumerable.Phoenix.LiveView.LiveStream.slice/1
      (elixir 1.18.1) lib/enum.ex:1019: Enum.empty?/1
  ```
- **Cause:** Used `Enum.empty?(@streams.rooms)` in template - LiveView streams are not enumerable
- **Solution:** 
  1. Added `:rooms_empty?` assign to track empty state manually
  2. Modified template to use `@rooms_empty?` instead of `Enum.empty?(@streams.rooms)`
  3. Updated stream operations to maintain empty state
- **Prevention:** Never use `Enum.*` functions on LiveView streams - they don't implement the Enumerable protocol
#### Error: Compilation warnings for unused functions in Hall LiveView
- **Date:** September 6, 2025
- **Context:** Compilation warnings appeared for unused private functions in `GameEightWeb.GameLive.Hall`
- **Error Message:** 
  ```
  warning: function stream_configure/1 is unused
  warning: function room_status_text/1 is unused  
  warning: function room_status_badge_class/1 is unused
  warning: function room_players_text/1 is unused
  warning: function load_public_rooms/1 is unused
  warning: function can_join_room?/1 is unused
  ```
- **Cause:** Hall LiveView template was simplified for debugging but utility functions were left unused
- **Solution:** Removed all unused private functions since current template only shows debug information
- **Prevention:** Regularly run `mix compile` to catch unused function warnings early
- **Files Modified:** 
  - `lib/game_eight_web/live/game_live/hall.ex`

#### Error: Protocol.UndefinedError - String.Chars not implemented for Phoenix.LiveView.Socket
- **Date:** September 6, 2025
- **Context:** Attempting to fix the stream enumerable error
- **Error Message:** 
  ```
  ** (Protocol.UndefinedError) protocol String.Chars not implemented for type Phoenix.LiveView.Socket
  ```
- **Cause:** Incorrectly called `stream(socket, :rooms, [])` instead of `stream(:rooms, [])`
- **Solution:** Fixed function call to use correct `stream/3` signature: `stream(:rooms, [])`
- **Prevention:** Remember LiveView stream function signatures - first arg is the stream name, not socket
- **Files Modified:** 
  - `lib/game_eight_web/live/game_live/room_index.ex`

### 4. Asset Pipeline Errors
*No errors documented yet - asset compilation verification pending*

### 5. Testing Errors
*No errors documented yet - test suite not run*

### 6. Deployment Errors
*No errors documented yet - deployment not attempted*

## Error Resolution Template

When documenting errors, use this format:

### Error: [Brief Description]
- **Date:** [When encountered]
- **Context:** [What we were trying to do]
- **Error Message:** [Exact error text]
- **Cause:** [Root cause analysis]
- **Solution:** [How it was fixed]
- **Prevention:** [How to avoid in future]
- **Files Modified:** [What files were changed]

## Known Potential Issues

Based on project analysis, these are potential issues to watch for:

### 1. Phoenix LiveView Common Issues
- **Issue:** `current_scope` assign errors
- **Cause:** Failing to follow authenticated routes guidelines
- **Prevention:** Always pass `current_scope` to `<Layouts.app>` and use proper `live_session`

### 2. Database Connection Issues
- **Issue:** PostgreSQL connection failures
- **Potential Cause:** Database not running or incorrect configuration
- **Prevention:** Verify PostgreSQL is running before starting development server

### 3. Asset Compilation Issues
- **Issue:** TailwindCSS or ESBuild compilation failures
- **Potential Cause:** Node.js version incompatibility or missing dependencies
- **Prevention:** Ensure Node.js 18+ is installed and run `mix assets.setup`

### 4. Elixir Version Compatibility
- **Issue:** Code not compiling due to Elixir version mismatch
- **Requirement:** Elixir 1.15+ required
- **Prevention:** Verify Elixir version with `elixir --version`

## Best Practices for Error Prevention

### Development Workflow
1. **Always run `mix precommit` before committing code**
   - Compiles with warnings as errors
   - Runs formatter
   - Executes test suite
   - Checks for unused dependencies

2. **Use proper Phoenix conventions**
   - Follow project guidelines in `AGENTS.md`
   - Use imported components from `core_components.ex`
   - Properly structure LiveView templates

3. **Database Best Practices**
   - Always create migrations for schema changes
   - Use Ecto changesets for validation
   - Test database operations in development

### Code Quality
1. **Follow Elixir conventions**
   - Use pattern matching appropriately
   - Avoid `String.to_atom/1` on user input
   - Handle errors with proper return tuples

2. **LiveView specific**
   - Use `<.form>` and `to_form/2` for forms
   - Access form fields via `@form[:field]`
   - Use `<.input>` component for form inputs

3. **Phoenix guidelines**
   - Use `<.icon>` component for Heroicons
   - Never use deprecated functions like `live_redirect`
   - Properly handle flash messages

## Error Monitoring Strategy

### During Development
- Monitor terminal output for compilation warnings
- Check browser console for JavaScript errors
- Watch LiveView debug information
- Review test failures immediately

### Testing Strategy
- Run `mix test` frequently during development
- Use `mix test --failed` to re-run only failed tests
- Implement comprehensive test coverage
- Test real-time functionality thoroughly

## Recovery Procedures

### If Environment Breaks
1. **Clean dependencies:** `mix deps.clean --all` (last resort only)
2. **Reset database:** `mix ecto.reset`
3. **Rebuild assets:** `mix assets.setup && mix assets.build`
4. **Restart server:** Stop and restart `mix phx.server`

### If Git Issues
1. **Check current branch:** `git branch`
2. **Review uncommitted changes:** `git status`
3. **Use feature branches:** Avoid working directly on main

### If Database Issues
1. **Check PostgreSQL status:** Ensure service is running
2. **Verify connection:** Check `config/dev.exs` settings
3. **Reset if needed:** `mix ecto.reset` to rebuild database

## Future Error Documentation

As development progresses, document all errors encountered:
1. **Immediate documentation:** Add errors as they occur
2. **Weekly review:** Analyze patterns in errors
3. **Solution sharing:** Document working solutions clearly
4. **Prevention updates:** Update best practices based on lessons learned

## Contact Information

For errors that cannot be resolved:
1. Check Phoenix documentation: https://hexdocs.pm/phoenix/
2. Review Elixir guides: https://elixir-lang.org/getting-started/
3. Search Elixir Forum: https://elixirforum.com/
4. Check project guidelines in `AGENTS.md`

---

*Note: This file will be updated as development progresses and errors are encountered. Always document errors immediately when they occur to maintain accurate records.*
