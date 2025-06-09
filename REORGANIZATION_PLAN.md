# Repository Reorganization Plan

## Proposed New Structure

```
dotfiles/
├── README.md                    # Main documentation
├── LICENSE                      # License file
├── CLAUDE.md                    # AI assistant instructions
├── bootstrap.sh                 # Unified bootstrap script
├── Makefile                     # Common tasks automation
│
├── config/                      # All configuration files
│   ├── cross-platform/          # Works on all supported OS
│   │   ├── git/
│   │   ├── nvim/
│   │   ├── tmux/
│   │   ├── zsh/
│   │   ├── bat/
│   │   └── python/
│   │
│   ├── macos/                   # macOS-specific configs
│   │   ├── defaults/            # System preferences
│   │   ├── homebrew/            # Package lists
│   │   ├── karabiner/           # Keyboard customization
│   │   ├── kitty/               # Terminal emulator
│   │   └── security/            # Hardening scripts
│   │
│   └── ubuntu/                  # Ubuntu-specific configs
│       └── apt/                 # Package lists
│
├── scripts/                     # Utility scripts (was bin/)
│   ├── cross-platform/          # Works everywhere
│   │   ├── backup
│   │   ├── extract
│   │   └── mkx
│   │
│   └── macos/                   # macOS-specific scripts
│       ├── osx-clock-toggle
│       └── cantsleep
│
├── install/                     # Installation scripts
│   ├── common.sh               # Shared functions
│   ├── macos.sh                # macOS installation
│   ├── ubuntu.sh               # Ubuntu installation
│   └── packages/               # Package lists by profile
│       ├── minimal.txt
│       ├── standard.txt
│       └── full.txt
│
├── docs/                       # Additional documentation
│   ├── DEPENDENCIES.md         # Required dependencies
│   ├── KEYBINDINGS.md         # Key binding reference
│   └── TROUBLESHOOTING.md     # Common issues
│
└── tests/                      # Validation scripts
    ├── validate-links.sh       # Check for broken symlinks
    ├── validate-syntax.sh      # Syntax checking
    └── test-bootstrap.sh       # Bootstrap testing

```

## Migration Steps

### 1. Consolidate Bootstrap Scripts
- [x] Create unified `bootstrap.sh` with profile support
- [ ] Remove old bootstrap variants
- [ ] Update CLAUDE.md with new bootstrap usage

### 2. Reorganize Config Directory
```bash
# Create new structure
mkdir -p config/{cross-platform,macos,ubuntu}

# Move cross-platform configs
for dir in git nvim tmux zsh bat python clang-format lldb; do
    mv config/$dir config/cross-platform/
done

# Move macOS-specific configs
mkdir -p config/macos/{defaults,security}
mv config/macos/*.zsh config/macos/defaults/
mv config/homebrew config/macos/
mv config/karabiner config/macos/
mv config/kitty config/macos/

# Create Ubuntu-specific directory
mkdir -p config/ubuntu/apt
```

### 3. Rename and Reorganize Scripts
```bash
# Rename bin/ to scripts/
mv bin scripts

# Organize by platform
mkdir -p scripts/{cross-platform,macos}
mv scripts/{backup,extract,mkx,*} scripts/cross-platform/
mv scripts/{osx*,cantsleep} scripts/macos/
```

### 4. Standardize Naming Conventions
- Use kebab-case for all scripts: `osx_clock_toggle` → `osx-clock-toggle`
- Use lowercase for all directory names
- Remove redundant prefixes in install scripts

### 5. Add Documentation
- [ ] Create docs/ directory with detailed guides
- [ ] Add README.md to each major config directory
- [ ] Document dependencies and version requirements

### 6. Create Helper Scripts
- [ ] Add Makefile for common tasks
- [ ] Create validation/test scripts
- [ ] Add update script for pulling latest changes

## Benefits of Reorganization

1. **Clear Platform Separation**: Easy to see what's cross-platform vs OS-specific
2. **Better Documentation**: Dedicated docs directory with guides
3. **Easier Maintenance**: Logical grouping makes updates simpler
4. **Profile-Based Installation**: Users can choose their installation level
5. **Testing Support**: Validation scripts ensure everything works
6. **Standardized Structure**: Consistent naming and organization

## Implementation Order

1. **Phase 1**: Bootstrap consolidation ✓
2. **Phase 2**: Directory reorganization
3. **Phase 3**: Documentation updates
4. **Phase 4**: Add testing/validation
5. **Phase 5**: Update CLAUDE.md and cleanup

## Backwards Compatibility

During transition:
- Keep old bootstrap.sh as symlink to new version
- Add deprecation warnings to old scripts
- Document migration path for existing users