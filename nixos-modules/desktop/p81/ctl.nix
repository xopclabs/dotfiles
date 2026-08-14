{ writers }:

writers.writePython3Bin "p81ctl" {} (builtins.readFile ./p81ctl.py)
