extends Node
class_name ServerStatusProbeAutoload
## Lightweight server status & latency probe independent from gameplay connection.
## Uses a throwaway ENetMultiplayerPeer and polls its state (no MultiplayerAPI construction).
## Emits: status_updated(online: bool, latency_ms: int)

signal status_updated(online: bool, latency_ms: int)

const NetworkManagerScript = preload("res://scripts/network_manager.gd")
const CONNECT_TIMEOUT_SEC: float = NetworkManagerScript.PROBE_CONNECT_TIMEOUT_SEC
const POLL_INTERVAL_SEC: float = NetworkManagerScript.PROBE_POLL_INTERVAL_SEC

var _probing: bool = false
var _peer: ENetMultiplayerPeer
var _start_ms: int = 0
var _timeout_timer: SceneTreeTimer

func request_probe() -> void:
	if _probing:
		print_debug("[Probe] Request ignored: already probing")
		return
	var address: String = NetworkManagerScript.ADDRESS
	var port: int = NetworkManagerScript.PORT
	_peer = ENetMultiplayerPeer.new()
	var err: int = _peer.create_client(address, port)
	if err != OK:
		print_debug("[Probe] create_client error %d" % err)
		emit_signal("status_updated", false, -1)
		return
	_start_ms = Time.get_ticks_msec()
	_probing = true
	print_debug("[Probe] Started probe to %s:%d" % [address, port])
	# Start polling
	_call_poll()
	# Set timeout
	call_deferred("_setup_timeout")

## Removed _resolve_address_port() in favor of central NetworkConfig

func _call_poll() -> void:
	if not _probing:
		return
	if not _peer:
		print_debug("[Probe] Poll called with null peer")
		_cleanup(false, -1)
		return
	_peer.poll()
	var state: int = _peer.get_connection_status()
	match state:
		MultiplayerPeer.CONNECTION_CONNECTING:
			# Still connecting; continue polling.
			pass
		MultiplayerPeer.CONNECTION_CONNECTED:
			var rtt: int = Time.get_ticks_msec() - _start_ms
			print_debug("[Probe] Connected in %d ms" % rtt)
			_cleanup(true, rtt)
			return
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			print_debug("[Probe] Disconnected during probe")
			_cleanup(false, -1)
			return
		_:
			print_debug("[Probe] Unknown state %d" % state)
	# Schedule next poll
	get_tree().create_timer(POLL_INTERVAL_SEC).timeout.connect(_call_poll, CONNECT_ONE_SHOT)

func _setup_timeout() -> void:
	_timeout_timer = get_tree().create_timer(CONNECT_TIMEOUT_SEC)
	await _timeout_timer.timeout
	if _probing:
		print_debug("[Probe] Timeout after %0.2f s" % CONNECT_TIMEOUT_SEC)
		_cleanup(false, -1)

func _cleanup(online: bool, latency_ms: int) -> void:
	if _peer:
		_peer.close()
	_peer = null
	_probing = false
	if _timeout_timer:
		_timeout_timer = null # Allow GC
	emit_signal("status_updated", online, latency_ms)
	print_debug("[Probe] Finished. online=%s latency=%d" % [str(online), latency_ms])
