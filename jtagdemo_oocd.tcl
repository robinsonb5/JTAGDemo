# Demo JTAG script using OpenOCD, which can't support the Tk GUI.

# Run like so:
# > openocd -f Demistify/Board/<board>/target.cfg -f jtagdemo_oocd.tcl

init
scan_chain

proc vir {v} {irscan target.tap 0x32; return [drscan target.tap 32 $v]}
proc vdr {v} {irscan target.tap 0x38; return [drscan target.tap 32 $v]}

proc colour {i} {
	vdr	[expr {65536*$i + 256*($i/2) + ($i/4)}]
}

# Write
vir 0x01

vdr 0x03000020
vdr 0x02000100
vdr 0xfd000000
for {set i 0} {$i < 50} {incr i} {
	after 30
	colour $i
}
vdr 0x020000aa
vdr 0xfd000000
for {set i 51} {$i < 100} {incr i} {
	after 30
	colour $i
}
vdr 0x02000080
vdr 0xfd000000
for {set i 101} {$i < 200} {incr i} {
	after 30
	colour $i
}

vdr 0x0200006b
vdr 0xfd000000
for {set i 201} {$i < 210} {incr i} {
	after 30
	colour $i
}

vdr 0x02000072
vdr 0xfd000000
for {set i 211} {$i < 255} {incr i} {
	after 30
	colour $i
}

after 600
vdr 0x01000200
vdr 0x03000200
for {set i 0} {$i < 8} {incr i} {
	vdr [expr {0x02000100 + ($i & 1) * 0x50}]
	vdr 0xfd000000
	after 400
}
exit

