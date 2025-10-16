# Simple OSC receiver for /bandTrigger messages
# Usage: python3 python_receiver.py --port 9000

from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer
import argparse

def on_band_trigger(addr, idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs):
    print(f"{addr} idx={idx} {fLo:.0f}-{fHi:.0f}Hz  E={energy:.2f}  T={threshold:.2f}  H={hysteresis:.2f}  C={cooldownMs}ms")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9000)
    args = ap.parse_args()

    disp = Dispatcher()
    disp.map("/bandTrigger", on_band_trigger)

    server = BlockingOSCUDPServer(("0.0.0.0", args.port), disp)
    print(f"Listening for /bandTrigger on UDP {args.port} ...")
    server.serve_forever()
