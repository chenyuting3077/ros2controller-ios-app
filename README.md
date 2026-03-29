# ROS2 Controller

A native iOS app for controlling a ROS2 robot via the [rosbridge](https://github.com/RobotWebTools/rosbridge_suite) WebSocket protocol.

## Features

- **Dual joystick control** — left stick for linear velocity (x/y), right stick for angular velocity (yaw); publishes `geometry_msgs/Twist`
- **Topic monitor** — live Hz and bandwidth display for any topic; watchlist persisted across sessions
- **Auto-reconnect** — exponential backoff (2s → 4s → 8s → capped at 30s) on connection loss
- **Persisted settings** — host, port, topic name, speed limits, and publish rate saved to UserDefaults

## Requirements

| Requirement | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 16.0+ |
| Swift | 5.9+ |
| rosbridge | 2.x / 3.x |

No external dependencies — uses `URLSessionWebSocketTask` for native WebSocket support.

## Robot Setup

Install and launch rosbridge on your robot:

```bash
# ROS2
sudo apt install ros-$ROS_DISTRO-rosbridge-server
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

The server listens on port **9090** by default.

## Usage

1. Open the app and go to the **Connect** tab.
2. Enter your robot's IP address and port (default: `9090`).
3. Tap **Connect**.
4. Switch to the **Control** tab and use the joysticks to drive.
5. Switch to the **Topics** tab to monitor message rates and bandwidth.

### Control Settings

Tap the gear icon on the Control tab to adjust:

- **Topic** — the `cmd_vel` topic name (default: `/cmd_vel`)
- **Max linear speed** — meters per second (0.1–2.0 m/s)
- **Max angular speed** — radians per second (0.1–3.0 rad/s)
- **Publish rate** — 5, 10, 20, or 50 Hz

## Architecture

```
ROS2Controller/
├── Models/
│   ├── AppSettings.swift       # @Observable, UserDefaults-backed settings
│   └── TopicStats.swift        # Per-topic Hz / bandwidth tracking
├── Managers/
│   └── ROSBridgeManager.swift  # WebSocket connection, publish/subscribe, auto-reconnect
└── Views/
    ├── ConnectionView.swift     # Host/port input, connect button, status
    ├── JoystickView.swift       # Dual-joystick layout + settings sheet
    ├── JoystickPadView.swift    # Reusable circular joystick widget
    └── TopicMonitorView.swift   # Topic list with Hz/BW and watchlist editing
```

State is managed with SwiftUI's `@Observable` macro and shared via the `@Environment` key.

## rosbridge Protocol

The app uses a subset of the [rosbridge v2 protocol](https://github.com/RobotWebTools/rosbridge_suite/blob/ros2/ROSBRIDGE_PROTOCOL.md):

| Operation | Use |
|---|---|
| `advertise` | Declare `/cmd_vel` on connect |
| `publish` | Send Twist messages |
| `call_service` | `/rosapi/topics` to list available topics |
| `subscribe` | Monitor individual topic message rates |
| `unsubscribe` | Stop monitoring a topic |

## License

MIT
