{
  "patcher" : {
    "fileversion" : 1,
    "rect" : [ 59.0, 104.0, 900.0, 600.0 ],
    "bglocked" : 0,
    "gridonopen" : 0,
    "gridsize" : [ 15.0, 15.0 ],
    "toolbarvisible" : 1,
    "boxes" : [
      {
        "box" : {
          "id" : "comment-title",
          "maxclass" : "comment",
          "patching_rect" : [ 30.0, 20.0, 420.0, 25.0 ],
          "text" : "frZone OSC listener — Signal Culture / TouchDesigner-friendly"
        }
      },
      {
        "box" : {
          "id" : "comment-intent",
          "maxclass" : "comment",
          "patching_rect" : [ 30.0, 45.0, 650.0, 45.0 ],
          "text" : "Drop this next to Interstream/Maelstrom or any Max-friendly rig. It mirrors examples/osc/python_receiver.py so newcomers can see end-to-end routing without hunting for objects."
        }
      },
      {
        "box" : {
          "id" : "comment-port",
          "maxclass" : "comment",
          "patching_rect" : [ 30.0, 95.0, 260.0, 25.0 ],
          "text" : "Listen on 9000 to match the TouchDesigner quickstart."
        }
      },
      {
        "box" : {
          "id" : "udp",
          "maxclass" : "newobj",
          "text" : "udpreceive 9000",
          "patching_rect" : [ 30.0, 120.0, 110.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "oscparse",
          "maxclass" : "newobj",
          "text" : "oscparse",
          "patching_rect" : [ 30.0, 155.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "route",
          "maxclass" : "newobj",
          "text" : "route bandEnergy bandTrigger",
          "patching_rect" : [ 30.0, 190.0, 200.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "comment-energy",
          "maxclass" : "comment",
          "patching_rect" : [ 30.0, 220.0, 280.0, 22.0 ],
          "text" : "/bandEnergy: idx, fLo, fHi, energyN (0..1)"
        }
      },
      {
        "box" : {
          "id" : "unpack-energy",
          "maxclass" : "newobj",
          "text" : "unpack i f f f",
          "patching_rect" : [ 30.0, 245.0, 140.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "num-idx",
          "maxclass" : "number",
          "patching_rect" : [ 30.0, 275.0, 50.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-flo",
          "maxclass" : "flonum",
          "patching_rect" : [ 90.0, 275.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-fhi",
          "maxclass" : "flonum",
          "patching_rect" : [ 170.0, 275.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-energy",
          "maxclass" : "flonum",
          "patching_rect" : [ 250.0, 275.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "comment-energy-note",
          "maxclass" : "comment",
          "patching_rect" : [ 330.0, 275.0, 350.0, 35.0 ],
          "text" : "Map this to sliders/knobs in Interstream or TouchDesigner (OSC In CHOP). Energy stays smooth thanks to frZone’s per-band smoothing."
        }
      },
      {
        "box" : {
          "id" : "comment-trigger",
          "maxclass" : "comment",
          "patching_rect" : [ 30.0, 320.0, 330.0, 22.0 ],
          "text" : "/bandTrigger: idx, fLo, fHi, energy, threshold, hysteresis, cooldownMs"
        }
      },
      {
        "box" : {
          "id" : "unpack-trigger",
          "maxclass" : "newobj",
          "text" : "unpack i f f f f f i",
          "patching_rect" : [ 30.0, 345.0, 180.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "num-idx-trig",
          "maxclass" : "number",
          "patching_rect" : [ 30.0, 375.0, 50.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-flo-trig",
          "maxclass" : "flonum",
          "patching_rect" : [ 90.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-fhi-trig",
          "maxclass" : "flonum",
          "patching_rect" : [ 170.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-energy-trig",
          "maxclass" : "flonum",
          "patching_rect" : [ 250.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-thresh",
          "maxclass" : "flonum",
          "patching_rect" : [ 330.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "float-hyst",
          "maxclass" : "flonum",
          "patching_rect" : [ 410.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "num-cooldown",
          "maxclass" : "number",
          "patching_rect" : [ 490.0, 375.0, 70.0, 22.0 ]
        }
      },
      {
        "box" : {
          "id" : "comment-trigger-note",
          "maxclass" : "comment",
          "patching_rect" : [ 570.0, 365.0, 280.0, 45.0 ],
          "text" : "Use trigger pulses for cuts, toggles, or Max bangs. Threshold/hysteresis/cooldown are exposed so the class can see the gating math."
        }
      },
      {
        "box" : {
          "id" : "comment-route",
          "maxclass" : "comment",
          "patching_rect" : [ 250.0, 220.0, 320.0, 22.0 ],
          "text" : "Left outlet = /bandEnergy, right outlet = /bandTrigger"
        }
      }
    ],
    "lines" : [
      { "patchline" : { "source" : [ "udp", 0 ], "destination" : [ "oscparse", 0 ] } },
      { "patchline" : { "source" : [ "oscparse", 0 ], "destination" : [ "route", 0 ] } },
      { "patchline" : { "source" : [ "route", 0 ], "destination" : [ "unpack-energy", 0 ] } },
      { "patchline" : { "source" : [ "route", 1 ], "destination" : [ "unpack-trigger", 0 ] } },
      { "patchline" : { "source" : [ "unpack-energy", 0 ], "destination" : [ "num-idx", 0 ] } },
      { "patchline" : { "source" : [ "unpack-energy", 1 ], "destination" : [ "float-flo", 0 ] } },
      { "patchline" : { "source" : [ "unpack-energy", 2 ], "destination" : [ "float-fhi", 0 ] } },
      { "patchline" : { "source" : [ "unpack-energy", 3 ], "destination" : [ "float-energy", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 0 ], "destination" : [ "num-idx-trig", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 1 ], "destination" : [ "float-flo-trig", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 2 ], "destination" : [ "float-fhi-trig", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 3 ], "destination" : [ "float-energy-trig", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 4 ], "destination" : [ "float-thresh", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 5 ], "destination" : [ "float-hyst", 0 ] } },
      { "patchline" : { "source" : [ "unpack-trigger", 6 ], "destination" : [ "num-cooldown", 0 ] } }
    ]
  }
}
