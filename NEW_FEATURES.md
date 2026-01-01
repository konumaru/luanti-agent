# New Features Summary

This document summarizes the new features added in response to user feedback.

## 1. UV Dependency Management

**What Changed:**
- Migrated Python project to use [uv](https://docs.astral.sh/uv/) for dependency management
- Added `uv.lock` file for reproducible builds
- Updated `pyproject.toml` with proper build configuration
- Updated all documentation to use `uv run` commands

**Benefits:**
- Faster dependency resolution and installation
- More reliable builds with locked dependencies
- Modern Python tooling
- Better development workflow

**Usage:**
```bash
cd agent
uv sync                    # Install dependencies
uv run python bot_server.py  # Run server
uv run python test_agent_client.py  # Run tests
```

**Files Modified:**
- `agent/pyproject.toml` - Added build-system and dependency-groups
- `agent/uv.lock` - New lock file
- `.gitignore` - Added uv patterns
- All documentation files (README.md, QUICKSTART.md, agent/README.md)

## 2. Visibility Filtering (Occlusion Detection)

**What Changed:**
- Added configurable filtering of underground/occluded blocks
- Implemented raycast-based line-of-sight checking
- Agents can toggle between realistic vision and x-ray vision

**How It Works:**
- Uses Minetest's raycast API to check if blocks are visible from agent's eye position
- Blocks within 1.5 blocks of agent are always considered visible
- Filter can be toggled on/off via Python API

**Python API:**
```python
from agent_client import SetObservationOptionsAction

# Enable filtering - only see visible blocks (realistic)
client.send_action(SetObservationOptionsAction(filter_occluded_blocks=True))

# Disable filtering - see all blocks (x-ray vision)
client.send_action(SetObservationOptionsAction(filter_occluded_blocks=False))
```

**Lua Implementation:**
- Added `filter_occluded_blocks` boolean to agent state
- Added `is_block_visible()` helper function using raycast
- Modified `get_surrounding_blocks()` to respect filter setting
- Added `action_set_observation_options()` function

**Files Modified:**
- `mods/agent_api/init.lua` - Core implementation
- `agent/agent_client.py` - Python action class
- `agent/test_agent_client.py` - Tests
- Documentation files

## 3. Chat Communication

**What Changed:**
- Agents can now send messages in the game chat
- Messages appear with the agent's name as the sender

**Python API:**
```python
from agent_client import ChatAction

client.send_action(ChatAction("Hello from AI agent!"))
client.send_action(ChatAction("I found diamonds!"))
```

**Lua Implementation:**
- Added `action_chat(agent, message)` function
- Uses `minetest.chat_send_all()` to broadcast messages
- Validates message is not empty before sending

**Use Cases:**
- Status updates ("Moving to location...")
- Discoveries ("Found ore at coordinates...")
- Player interaction ("Hello! I'm an AI agent")
- Debugging ("Current state: exploring")

**Files Modified:**
- `mods/agent_api/init.lua` - Implementation
- `agent/agent_client.py` - Python action class
- `agent/test_agent_client.py` - Tests
- Documentation files

## 4. Example Script

**New File:** `agent/example_new_features.py`

Demonstrates all new features with three modes:

```bash
# Visibility filtering demo
uv run python example_new_features.py visibility

# Chat demo
uv run python example_new_features.py chat

# Combined demo (movement + visibility + chat)
uv run python example_new_features.py combined
```

## Testing

All features are fully tested:

```bash
cd agent
uv run python test_agent_client.py
```

**Results:** 8/8 action types tested and passing
- MoveAction ✓
- RotateAction ✓
- LookAtAction ✓
- DigAction ✓
- PlaceAction ✓
- UseAction ✓
- SetObservationOptionsAction ✓ (NEW)
- ChatAction ✓ (NEW)

## Documentation Updates

All documentation has been updated to reflect the new features:

1. **API.md**
   - Added Lua API documentation for new actions
   - Added Python API documentation for new classes
   - Updated action format examples

2. **agent/README.md**
   - Added "New Features" section
   - Updated available actions list
   - Added usage examples

3. **mods/agent_api/README.md**
   - Updated feature list
   - Added Lua API examples

4. **QUICKSTART.md**
   - Updated all commands to use `uv run`

5. **README.md**
   - Updated quick start commands
   - Updated example commands

## Code Quality

- All code review issues addressed
- Magic numbers extracted to named constants
- Comprehensive error handling
- Clean, maintainable code structure
- Type-safe Python implementations

## Backward Compatibility

All changes are backward compatible:
- Existing code continues to work without modification
- New features are opt-in
- Default behavior unchanged (filter_occluded_blocks=false by default)

## Performance Considerations

**Visibility Filtering:**
- Raycast is efficient for small observation radii
- Only performed when filter is enabled
- Close blocks (< 1.5 distance) skip raycast for performance

**Chat:**
- Minimal performance impact
- Validates messages before sending
- Debug logging available for troubleshooting
