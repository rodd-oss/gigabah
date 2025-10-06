extends Resource
class_name NetworkConfig
## Centralized network configuration constants.
## Use these instead of duplicating literals across scripts.

const ADDRESS: String = "gigabuh.d.roddtech.ru"
const PORT: int = 25445
const PROBE_CONNECT_TIMEOUT_SEC: float = 1.5
const PROBE_POLL_INTERVAL_SEC: float = 0.05
const PING_INTERVAL_SEC: float = 2.0 # Interval for runtime RTT ping (client side)
