# GNet - Godot Networking Framework

A comprehensive networking framework for Godot 4 that provides:

- **Multiple Network Adapters**: Steam P2P and ENet support
- **Unified Lobby System**: Cross-platform lobby management 
- **Message Bus Architecture**: Type-safe, event-driven networking
- **Runtime Management**: Seamless server/client lifecycle handling
- **UI Components**: Ready-to-use networking HUD

## Quick Start

1. Enable the GNet plugin in Project Settings
2. The autoloads will be automatically configured
3. Use `NetCore.start_host()` or `NetCore.join_session()` to begin
4. See the examples folder for complete implementations

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md)
- [API Reference](docs/API.md)
- [Steam Setup](docs/STEAM_SETUP.md)
- [Dedicated Server Guide](docs/DEDICATED_GUIDE.md)

## Features

- Cross-platform networking (Steam P2P, ENet)
- Automatic NAT traversal via Steam
- Lobby discovery and management
- Message serialization and routing
- Connection state management
- Built-in debugging tools
