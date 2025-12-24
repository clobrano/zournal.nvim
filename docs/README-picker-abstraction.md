# Picker Abstraction Documentation

This directory contains comprehensive documentation for the picker abstraction layer that allows zournal.nvim to support multiple fuzzy finder backends.

## Documents Overview

### 1. [Picker Abstraction Design](picker-abstraction-design.md)
**Purpose:** High-level architecture and design decisions

**Contents:**
- Current state analysis of Telescope usage
- Comparison between Telescope and FzfLua APIs
- Proposed abstraction layer architecture
- Migration path (4 phases)
- Configuration changes
- Testing strategy
- Benefits and limitations

**Read this if:** You want to understand the overall design and architecture

### 2. [Picker Comparison](picker-comparison.md)
**Purpose:** Detailed feature-by-feature comparison

**Contents:**
- API comparison matrix
- Feature parity check for all 4 pickers
- Performance comparison (small/medium/large datasets)
- UX differences (appearance, keybindings)
- Dependencies and install sizes
- Recommendation and conclusion

**Read this if:** You want to understand specific differences between Telescope and FzfLua

### 3. [Implementation Plan](picker-implementation-plan.md)
**Purpose:** Detailed task breakdown for implementation

**Contents:**
- 6 implementation phases with time estimates
- Detailed tasks for each phase
- Test cases and success criteria
- Risk assessment
- Timeline estimate (7-10 hours total)
- Rollback plan
- Future enhancements

**Read this if:** You're ready to implement the abstraction layer

## Quick Summary

### The Problem
Zournal.nvim currently has a **hard dependency on Telescope**, which:
- Forces all users to install Telescope (even if they prefer FzfLua)
- Locks the plugin into one picker ecosystem
- Increases overall dependency footprint

### The Solution
Create an **abstraction layer** that:
- Supports both Telescope and FzfLua backends
- Auto-detects which picker is installed
- Allows user configuration: `picker_backend = 'auto' | 'telescope' | 'fzflua'`
- Maintains full feature parity between backends
- Requires zero changes for existing Telescope users

### Key Benefits
1. **Reduced dependencies** - Telescope becomes optional
2. **User flexibility** - Choose preferred picker
3. **Better performance** - FzfLua is faster for large datasets
4. **Future-proof** - Easy to add more backends later
5. **No breaking changes** - Backward compatible

### Implementation Effort
- **Time Estimate:** 7-10 hours
- **Risk Level:** Low (backward compatible)
- **Complexity:** Medium (clear abstraction pattern)

### Architecture

```
Application Code (relations.lua, links.lua, etc.)
    ↓
picker.show(config) — Unified interface
    ↓
    ├─→ telescope_adapter.lua (Telescope backend)
    └─→ fzflua_adapter.lua (FzfLua backend)
```

### Feature Parity
All four pickers work identically with both backends:
- ✅ **Relations picker** - Browse parent/siblings/children
- ✅ **Links picker** - Show all links with broken link detection
- ✅ **Tag references picker** - Find all tag occurrences with line jump
- ✅ **Calendar picker** - Browse dates with custom preview

## Implementation Phases

### Phase 1: Foundation (2-3 hours)
Create base picker module and both adapters

### Phase 2: Proof of Concept (1 hour)
Migrate links picker to validate design

### Phase 3: Complete Migration (2-3 hours)
Migrate remaining 3 pickers

### Phase 4: Cleanup & Docs (1 hour)
Remove old code, update README

### Phase 5: Testing (1-2 hours)
Comprehensive testing with both backends

### Phase 6: Release (30 min)
Version bump, changelog, release

## Next Steps

1. **Review Documents:**
   - Read the design document for architecture understanding
   - Review the comparison for feature parity confidence
   - Study the implementation plan for task details

2. **Decision Point:**
   - Approve the design approach
   - Decide on timeline and priority
   - Allocate development time

3. **Implementation:**
   - Follow the 6-phase plan
   - Test thoroughly with both backends
   - Update documentation

4. **Release:**
   - Communicate changes to users
   - Update README with new dependency info
   - Create release notes

## Files Created

```
docs/
├── README-picker-abstraction.md          (this file)
├── picker-abstraction-design.md          (12 KB)
├── picker-comparison.md                  (9.1 KB)
└── picker-implementation-plan.md         (15 KB)
```

## Code Structure (After Implementation)

```
lua/zournal/
├── picker.lua                            (unified interface)
├── picker/
│   ├── telescope_adapter.lua             (Telescope backend)
│   └── fzflua_adapter.lua                (FzfLua backend)
└── pickers/                              (renamed from telescope/)
    ├── relations.lua
    ├── links.lua
    ├── tag_references.lua
    └── calendar.lua
```

## Testing Checklist

Before considering implementation complete:

- [ ] All pickers work with Telescope backend
- [ ] All pickers work with FzfLua backend
- [ ] Auto-detection works correctly
- [ ] Configuration validation works
- [ ] Error messages are helpful
- [ ] Documentation is complete
- [ ] Existing users have zero breaking changes
- [ ] Performance is acceptable

## References

- [Telescope Documentation](https://github.com/nvim-telescope/telescope.nvim)
- [FzfLua Documentation](https://github.com/ibhagwan/fzf-lua)
- [FzfLua Advanced Wiki](https://github.com/ibhagwan/fzf-lua/wiki/Advanced)

## Questions or Feedback?

If you have questions about the design or implementation:

1. Review the three main documents in order
2. Check the implementation plan for specific tasks
3. Refer to the comparison document for feature details

## License

Same as zournal.nvim (MIT)
