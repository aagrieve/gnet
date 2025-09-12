# gNet Quickstart (Godot 4 + GodotSteam)

This guide gets you hosting and joining via **SteamMultiplayerPeer** (listen-server).  
It also shows an optional **ENet loopback** mode for two-window local testing.

---

## 0) Prerequisites

1. Install **GodotSteam** for Godot 4 and enable it in your project.  
2. Ensure the **Steam client** is running and you are logged in.  
3. Place a `steam_appid.txt` file with your AppID in your project root for local runs.  
4. Enable this addon:  
   - Project → Project Settings → **Plugins** → gNet → Enable.  

---

## 1) Minimal setup (Steam, listen-server)

In a bootstrap script or autoload:

```gdscript
NetCore.use_adapter("steam")
NetCore.set_mode("listen_server") # or "client"
NetCore.set_version("1.0.0")
```

### Host
```gdscript
# Optionally create a Steam lobby first:
var lobby_id = Lobby.create({
    "capacity": 8,
    "visibility": "friends",
    "metadata": {"protocol":"1.0.0","mode":"listen"}
})

# Start hosting
NetCore.host({"tickrate_hz": 30})
```

### Join (from another machine/account)
```gdscript
var lobbies = Lobby.list({"protocol":"1.0.0"})
var host_steam_id = Lobby.join(lobbies[0].id)

NetCore.set_mode("client")
NetCore.connect(host_steam_id)
```

Your existing RPCs work as-is — the addon just swaps the active `MultiplayerPeer` under `SceneTree.multiplayer`.

---

## 2) Local testing (ENet loopback, optional)

If you want to test on a single PC without two Steam accounts:

**Host window (terminal A):**
```
--adapter=enet --mode=listen_server --host --port=3456 --userdir=_a
```

**Client window (terminal B):**
```
--adapter=enet --mode=client --join=127.0.0.1:3456 --userdir=_b
```

(Implement CLI parsing in your game init; call `NetCore.use_adapter(...)`,  
`NetCore.set_mode(...)`, then `host()` or `connect()` accordingly.)

---

## 3) Messages & channels

Register message types and listen for messages:

```gdscript
MessageBus.register_message("chat", MessageBus.CH_RELIABLE_ORDERED)
MessageBus.register_message("input", MessageBus.CH_UNRELIABLE_SEQUENCED)

MessageBus.connect("message", Callable(self, "_on_net_message"))

func _on_net_message(t, from_peer, payload):
    if t == "chat":
        print("[", from_peer, "] ", payload.get("text"))
```

Send a message:

```gdscript
MessageBus.send("chat", {"text":"hello"})
```

---

## 4) Dedicated server (preview)

- **Path A (MVP): ENet headless**
  - Build headless export. Start:
    ```
    --adapter=enet --mode=dedicated --port=3456 --max_peers=8
    ```
  - Clients connect by address/port (you can still publish an entry in a Steam lobby with the address in metadata).

- **Path B (later): Steam Game Server**
  - Run a Steam game server via GodotSteam server APIs; clients discover/connect through Steam (no port forwarding).

---

## 5) Net HUD

Drop `addons/gNet/ui/NetHUD.tscn` into your scene during development to see peers/traffic basics.

---

## 6) Troubleshooting

- **Steam not running** → start Steam client.  
- **Can’t join self** → expected for Steam; test with a second machine/account or use ENet loopback.  
- **Version mismatch** → ensure `NetCore.set_version()` matches lobby `protocol` metadata.  
- **Firewalls** → allow the app; for ENet dedicated, open the server port.  

---

## 7) Next steps

- Read `STEAM_SETUP.md` for lobby metadata and testing tips.  
- See `MESSAGES.md` for reliability guidance and payload size caps.  
- Try the example scenes under `/examples`.  
