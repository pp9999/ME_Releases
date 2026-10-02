import sys, os, json, http.client, argparse
from urllib.parse import urlparse

def _to_ascii(text):
    """Escape non-ASCII characters so payloads are guaranteed 7-bit ASCII."""
    if not isinstance(text, str):
        return text
    return text.encode("ascii", "backslashreplace").decode("ascii")

if sys.platform == "win32":
    import msvcrt
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
_mcp_stdout = sys.stdout
sys.stdout = sys.stderr
try:
    from mcp.server.fastmcp import FastMCP
except ImportError as exc:
    print(_to_ascii("[BotMCP] Import error: {}".format(exc)), file=sys.stderr, flush=True)
    sys.exit(1)
sys.stdout = _mcp_stdout

# ASCII-only MCP stdio transport. The SDK wraps stdio with its own text layer;
# replace it so stdout can never carry non-ASCII bytes (encoding="ascii" plus
# xmlcharrefreplace turns any stray character into an XML reference instead of
# crashing) and lines end with LF only, not CRLF.
if sys.platform == "win32":
    from io import TextIOWrapper
    from contextlib import asynccontextmanager
    import anyio
    import mcp.server.stdio as mcp_stdio
    import mcp.server.fastmcp.server as fastmcp_server

    _sdk_stdio_server = mcp_stdio.stdio_server

    @asynccontextmanager
    async def _ascii_stdio_server(stdin=None, stdout=None):
        if stdin is None:
            stdin = anyio.wrap_file(TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace"))
        if stdout is None:
            stdout = anyio.wrap_file(TextIOWrapper(sys.stdout.buffer, encoding="ascii", errors="xmlcharrefreplace", newline="\n"))
        async with _sdk_stdio_server(stdin=stdin, stdout=stdout) as streams:
            yield streams

    mcp_stdio.stdio_server = _ascii_stdio_server
    fastmcp_server.stdio_server = _ascii_stdio_server

BOT_HOST = "127.0.0.1"
BOT_PORT = 18642
_rpc_id = 0
def _call(method, params=None, timeout=10):
    global _rpc_id
    _rpc_id += 1
    req = {"jsonrpc":"2.0","method":method,"params":[params or {}],"id":_rpc_id}
    try:
        conn = http.client.HTTPConnection(BOT_HOST, BOT_PORT, timeout=timeout)
        conn.request("POST", "/mcp", json.dumps(req, ensure_ascii=True), {"Content-Type":"application/json"})
        resp = conn.getresponse()
        data = json.loads(resp.read().decode("utf-8", errors="replace"))
        conn.close()
    except Exception as exc:
        raise ConnectionError("BotMCPServer not reachable at {}:{} ({})".format(BOT_HOST, BOT_PORT, _to_ascii(str(exc))))
    if "error" in data:
        err = data["error"]
        raise RuntimeError("RPC error {}: {}".format(err.get("code"), _to_ascii(str(err.get("message")))))
    return data.get("result")
def _fmt(r):
    if isinstance(r, str):
        return _to_ascii(r)
    return json.dumps(r, ensure_ascii=True)
mcp = FastMCP("botclient")
@mcp.tool()
def check_connection():
    """Check if the bot client DLL is running and reachable."""
    try:
        p = _call("get_player")
        return _to_ascii("Connected. Player: {}".format(p.get("localPlayerName","?") if isinstance(p,dict) else "?"))
    except Exception as exc:
        return _to_ascii("Not connected: {}".format(exc))

@mcp.tool()
def get_main_data():
    """Get P_toMainData pointer - all game data tables are at this + offset."""
    return _fmt(_call("get_main_data"))

@mcp.tool()
def get_localplayer():
    """Get LocalPlayer pointer address and name."""
    return _fmt(_call("get_localplayer"))

@mcp.tool()
def get_player():
    """Get the current player snapshot (coords, health, prayer, skills, etc)."""
    return _fmt(_call("get_player"))
@mcp.tool()
def get_events():
    """Get recent game events: xp gains, chat messages, damage splats."""
    return _fmt(_call("get_events"))
@mcp.tool()
def get_entities(types=None, ids=None, names=None, max_dist=20):
    """Get nearby entities. types: 0=Object 1=NPC 2=Player 3=GroundItem 5=Projectile 12=Decor
    Entries include mem (entity object ptr) and memE (passObjMap key / work buffer ptr)."""
    params = {"max_dist": max_dist}
    if types  is not None: params["types"]  = types
    if ids    is not None: params["ids"]    = ids
    if names  is not None: params["names"]  = names
    return _fmt(_call("get_entities", params))
@mcp.tool()
def get_registry():
    """List all registered bot commands with their parameter signatures."""
    return _fmt(_call("get_registry"))
@mcp.tool()
def invoke(method, params="{}"):
    """Invoke any registered bot command by name. params is a JSON object string."""
    try:
        if isinstance(params, dict):
            obj = params
        else:
            obj = json.loads(params)
    except json.JSONDecodeError as exc:
        return _to_ascii("Error: invalid params JSON - {}".format(exc))
    return _fmt(_call("invoke", {"method": method, "params": obj}, timeout=45))
@mcp.tool()
def player_get():
    """Full player snapshot."""
    return _fmt(_call("invoke", {"method":"Player.Get","params":{}}))
@mcp.tool()
def inventory_get_items():
    """Get all items currently in the inventory."""
    return _fmt(_call("invoke", {"method":"Inventory.GetItems","params":{}}))
@mcp.tool()
def equipment_get_items():
    """Get all currently equipped items."""
    return _fmt(_call("invoke", {"method":"Equipment.GetItems","params":{}}))
@mcp.tool()
def cache_get_item(id=None, name=None):
    """Get item data from cache by ID or name. e.g. id=29323 or name='Incandescent energy'

    id may arrive as a string over MCP; the bridge requires a JSON number, so coerce it.
    A non-numeric id is treated as a name lookup instead."""
    params = {}
    if id is not None:
        try:
            params["id"] = int(id)
        except (TypeError, ValueError):
            params["name"] = str(id)
    elif name is not None:
        params["name"] = name
    return _fmt(_call("invoke", {"method":"Cache.GetItem","params":params}))
@mcp.tool()
def cache_find_items(name, partial=True):
    """Search cache items by name. e.g. name='energy'

    partial must be a real JSON boolean - the bridge rejects the string "false"."""
    if isinstance(partial, str):
        partial = partial.strip().lower() not in ("false", "0", "no", "")
    return _fmt(_call("invoke", {"method":"Cache.FindItems","params":{"name":name,"partial":bool(partial)}}))
@mcp.tool()
def cache_dump_item_raw(id):
    """Dump raw ItemObject fields from cache by ID. Use to debug opcode parsing."""
    return _fmt(_call("invoke", {"method":"Cache.DumpItemRaw","params":{"id":int(id)}}))
@mcp.tool()
def interface_read_on_demand(id=None):
    """Read a live interface group from the per-frame interface draw cache.
    id: interface group id (e.g. 517 = bank, 1622 = loot window). Omit or 0 to dump all open interfaces."""
    params = {}
    if id is not None:
        params["id"] = int(id)
    return _fmt(_call("invoke", {"method":"InterfaceReadOnDemand","params":params}, timeout=45))
@mcp.tool()
def interface_draw_cache_pointers():
    """Dump raw interface draw-cache pointer records (slot vector begin/end, ifaceId, uniform, clip rect)."""
    return _fmt(_call("invoke", {"method":"InterfaceDraw_cache_pointers","params":{}}, timeout=45))
@mcp.tool()
def var_read_varp(id):
    """Read a live varplayer settings node by id (varbits debug). Returns state (SettingsState = live value), addr, addrSpot, found, valid."""
    return _fmt(_call("invoke", {"method":"Var.ReadVarp","params":{"id":int(id)}}, timeout=45))
@mcp.tool()
def var_read_varc(id):
    """Read a live varclient settings node by id (varbits debug). Returns state (SettingsState = live value), addr, addrSpot, found, valid."""
    return _fmt(_call("invoke", {"method":"Var.ReadVarc","params":{"id":int(id)}}, timeout=45))
@mcp.tool()
def var_vp_findpsett(id, start_bit=None, end_bit=None):
    """Look up a varplayer base var (VP_FindPSett) and optionally extract a bitfield from state. start_bit/end_bit inclusive (0-31)."""
    params = {"id": int(id)}
    if start_bit is not None:
        params["startBit"] = int(start_bit)
    if end_bit is not None:
        params["endBit"] = int(end_bit)
    return _fmt(_call("invoke", {"method":"Var.VP_FindPSett","params":params}, timeout=45))
@mcp.tool()
def var_vc_findpsett(id, start_bit=None, end_bit=None):
    """Look up a varclient base var (VC_FindPSett) and optionally extract a bitfield from state. start_bit/end_bit inclusive (0-31)."""
    params = {"id": int(id)}
    if start_bit is not None:
        params["startBit"] = int(start_bit)
    if end_bit is not None:
        params["endBit"] = int(end_bit)
    return _fmt(_call("invoke", {"method":"Var.VC_FindPSett","params":params}, timeout=45))
@mcp.tool()
def interact_npc(name, action):
    """Interact with a nearby NPC. action e.g. Attack, Talk-to, Trade"""
    return _fmt(_call("invoke", {"method":"Interact.NPC","params":{"name":name,"action":action}}))
@mcp.tool()
def interact_object(name, action):
    """Interact with a nearby game object. action e.g. Open, Mine, Chop down"""
    return _fmt(_call("invoke", {"method":"Interact.Object","params":{"name":name,"action":action}}))

@mcp.tool()
def player_position():
    """Get the current world tile position (x, y, z/plane)."""
    p = _call("get_player")
    if isinstance(p, dict):
        c = p.get("coords") or {}
        return _fmt({"x": c.get("x"), "y": c.get("y"), "z": c.get("z")})
    return _fmt(p)

@mcp.tool()
def skills_get_all():
    """Get all skill levels and XP for the current player."""
    return _fmt(_call("invoke", {"method":"Skills.GetAll","params":{}}))

@mcp.tool()
def grand_exchange_get_data():
    """Get the current state of all Grand Exchange slots.

    The bridge exposes this as GrandExchange.GetData; GrandExchange.GetSlots
    does not exist and returns method_not_found."""
    return _fmt(_call("invoke", {"method":"GrandExchange.GetData","params":{}}))

@mcp.tool()
def mem_read(address, type="uint32", offsets=None):
    """Read a value from game memory at the given address.
    address: hex string e.g. '0x1234ABCD'
    type: uint8 int8 uint16 int16 uint32 int32 uint64 float
    offsets (optional): list of int offsets for pointer-chain dereference: *(*(addr+off0)+off1)+...
    Returns: address (input), resolved (final address after offset chain), value.
    Use for game diagnostics - reading live values at known offsets."""
    params = {"address": address, "type": type}
    if offsets:
        params["offsets"] = offsets
    return _fmt(_call("mem_read", params))

@mcp.tool()
def mem_read_bytes(address, size=256, offsets=None):
    """Read a raw range of bytes from game memory (memcpy via ME::Mem_COPY).
    address: hex string e.g. '0x1234ABCD'
    size: number of bytes to read (default 256, max 1048576)
    offsets (optional): list of int offsets for pointer-chain dereference before the read: *(*(addr+off0)+off1)+...
    Returns: address, resolved, size, ok, hex (space-separated) and ascii preview.
    Use to inspect the layout of memory structures byte by byte."""
    params = {"address": address, "size": int(size)}
    if offsets:
        params["offsets"] = offsets
    return _fmt(_call("mem_read_bytes", params))

@mcp.tool()
def mem_write(address, type, value):
    """Write a value to game memory at the given address.
    address: hex string e.g. '0x1234ABCD'
    type: bool uint8 int8 uint16 int16 uint32 int32 uint64 float
    value: numeric value to write
    Use for patching bool flags and conditional jumps in the game engine."""
    if isinstance(value, str):
        try:
            value = float(value) if type == "float" else int(value, 0)
        except (TypeError, ValueError):
            try:
                value = float(value) if type == "float" else int(value)
            except (TypeError, ValueError):
                pass
    return _fmt(_call("mem_write", {"address": address, "type": type, "value": value}))

@mcp.tool()
def mem_patch(address, bytes_):
    """Write raw bytes to memory using VirtualProtect for RX pages.
    address: hex string e.g. '0x1234ABCD'
    bytes_: list of int byte values e.g. [0x90, 0x90, 0x90] or hex string list
    Use for patching executable code sections."""
    if isinstance(bytes_, str):
        bytes_ = [int(b, 16) for b in bytes_.split()]
    return _fmt(_call("mem_patch", {"address": address, "bytes": bytes_}))

@mcp.tool()
def aob_scan(pattern, region="exe", max_results=50):
    """Scan game memory for an array-of-bytes pattern to locate functions or data.
    pattern: space-separated hex bytes with optional wildcards e.g. 'AA BB ? CC DD'
    region: 'exe' to scan the game executable region (default)
    max_results: maximum number of match addresses to return (default 50)"""
    return _fmt(_call("aob_scan", {"pattern": pattern, "region": region, "max_results": int(max_results)}))

@mcp.tool()
def audio_chunk_debug():
    """Dump the last AudioChunk detour state: table bounds, first entry sizes/pointers, first 8 float samples from l_ptr.
    Use to diagnose format mismatches (bytes vs samples, float32 vs int16)."""
    return _fmt(_call("audio_chunk_debug"))

@mcp.tool()
def mouse_move(x, y):
    """Move the mouse cursor to screen coordinates (x, y).
    Use for analyzing mouse movement paths in the game engine."""
    return _fmt(_call("mouse_move", {"x": int(x), "y": int(y)}))

@mcp.tool()
def mouse_left_click(x, y, sleep=50, random=30):
    """Perform a left mouse click at screen coordinates (x, y).
    sleep: base delay in ms after click (default 50)
    random: random extra delay in ms (default 30)
    Use for testing mouse interaction paths in the game engine."""
    return _fmt(_call("mouse_left_click", {"x": int(x), "y": int(y), "sleep": int(sleep), "random": int(random)}))

@mcp.tool()
def get_hooks():
    """Get addresses of all active Detours hooks (orig, detour, exe-relative offset).
    Use to locate hooked functions in the live process for breakpoints or cross-referencing."""
    return _fmt(_call("get_hooks"))

@mcp.tool()
def ring_entry_debug():
    """Get last WriteRingEntry detour state: a1, bufPtr, idp3, table_id.
    Use mem_read to follow idp3+0x8 for the OGG data pointer."""
    return _fmt(_call("ring_entry_debug"))

@mcp.tool()
def js5_decompress_debug(limit=100):
    """Get the JS5_DecompressGroup detour log: decompressed cache group data.
    The log is a capped ring buffer (last 1024 calls); use set_debug_hooks(js5=true)
    or the "JS5 Cache Loads" window to activate the lazy hook.
    limit: max entries to return, most recent (default 100, max 1000)
    Returns {count, returned, entries: [{data_ptr, data_size, archive_id,
    archive_type, archive_type_name, group_id, crc, version, status}]}."""
    return _fmt(_call("js5_decompress_debug", {"limit": int(limit)}))

@mcp.tool()
def get_spawned_objects():
    """Get all spawned/destroyed game objects from pass_obj_spawn/del hooks.
    Returns {count, entries: [{address, tick, time, id, tile_x, tile_y, plane}]}."""
    return _fmt(_call("get_spawned_objects"))

@mcp.tool()
def get_console():
    """Get the live console_text log from the DLL (JS5, collision, etc).
    Returns {text: string}."""
    return _fmt(_call("get_console"))

@mcp.tool()
def get_game_packets(limit=100, direction="both"):
    """Get captured game packets from the ReadIncomingMessage (S->C) and
    FlushClientMessages (C->S) hooks. Hooks are lazy: they only run while
    set_debug_hooks(s2c/c2s=true) or their ImGui windows are open.
    limit: max packets to return (default 100, max 1000)
    direction: 'in' (server->client), 'out' (client->server), or 'both' (default)
    Returns {count, total, packets: [{direction, opcode, name, size, data_hex}]}."""
    params = {"limit": int(limit), "direction": direction}
    return _fmt(_call("get_game_packets", params))

@mcp.tool()
def set_packet_capture(enabled=True):
    """Enable/disable game packet capture (g_gamePackets).
    Capture is on by default and does not depend on any ImGui window/toggle."""
    return _fmt(_call("set_packet_capture", {"enabled": bool(enabled)}))

@mcp.tool()
def set_debug_hooks(s2c=None, c2s=None, js5=None):
    """Force-activate the lazy debug detours without opening their ImGui windows.
    s2c: S->C ReadIncomingMessage detour
    c2s: C->S FlushClientMessages detour
    js5: JS5_DecompressGroup detour
    Only the keys provided are changed; each stays active while its bool is true
    OR its debug window is open. Call with no args to just read current state.
    Returns {ok, s2c, c2s, js5}."""
    params = {}
    if s2c is not None: params["s2c"] = bool(s2c)
    if c2s is not None: params["c2s"] = bool(c2s)
    if js5 is not None: params["js5"] = bool(js5)
    return _fmt(_call("set_debug_hooks", params))

@mcp.tool()
def get_tile(x, y, plane=0):
    """Get tile collision properties at world coords (x,y,plane).
    Returns {found, blocked, terrain, terrain_name, walkable, region_x, region_y, local_x, local_y}."""
    return _fmt(_call("get_tile", {"x": int(x), "y": int(y), "plane": int(plane)}))

@mcp.tool()
def get_player_tile():
    """Get collision properties at the player's current tile.
    No params - uses PlayerCoord() internally, handles instance offset."""
    return _fmt(_call("get_player_tile"))

@mcp.tool()
def astar_path(sx, sy, gx, gy, plane=0, limit=10000):
    """A* pathfinder using live JS5 collision data. 8-directional movement.
    Returns {reached, explored, limit, path_length, path: [{x,y}...], instance_off_x, instance_off_y}."""
    return _fmt(_call("astar_path", {
        "sx": int(sx), "sy": int(sy), "gx": int(gx), "gy": int(gy),
        "plane": int(plane), "limit": int(limit)
    }))


def main():
    global BOT_HOST, BOT_PORT
    parser = argparse.ArgumentParser(description="MemoryError Bot Client MCP Server")
    parser.add_argument("--bot-rpc", type=str, default="http://127.0.0.1:18642")
    args = parser.parse_args()
    parsed = urlparse(args.bot_rpc)
    if parsed.hostname and parsed.port:
        BOT_HOST = parsed.hostname
        BOT_PORT = parsed.port
    try:
        mcp.run(transport="stdio")
    except KeyboardInterrupt:
        pass
if __name__ == "__main__":
    main()
