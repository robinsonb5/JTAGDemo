#!/opt/intelFPGA_lite/18.1/quartus/bin/quartus_stp -t

#   jtagbridge.tcl - Virtual JTAG proxy for Altera devices

package require Tk

source [file dirname [info script]]/DeMiSTify/EightThirtyTwo/tcl/vjtagutil.tcl

####################### Main code ###################################

proc updatedisplay {} {
	global connected
	global red
	global green
	global blue
	global status
	global framecount

	if {$connected} {
		if [ vjtag::usbblaster_open ] {
			vjtag::send [expr $red * 256 * 256 + $green * 256 + $blue]
			set framecount [vjtag::recv_blocking]
			set status [vjtag::dec2bin [vjtag::recv_blocking] 32]
			# A dummy read to clear the FIFO if sync was lost and it contains stale data.
			set resync [vjtag::recv] 
		}
		vjtag::usbblaster_close
	}
	after 50 updatedisplay
}

proc send_reset {} {
	global connected
	set contmp $connected;
	set connected 0
	if {$contmp} {
		if [ vjtag::usbblaster_open] {
			vjtag::send [expr 255 * 256 * 256 * 256]
		}
		vjtag::usbblaster_close
	}
	set connected $contmp
}


proc connect {} {
	global displayConnect
	global connected
	set connected 0

	if { [vjtag::select_instance 0x55aa] < 0} {
		set displayConnect "Connection failed\n"
		set connected 0
	} else {
		set displayConnect "Connected to:\n$::vjtag::usbblaster_name\n$::vjtag::usbblaster_device"
		set connected 1
	}
}


global connected
set connected 0

global red
global green
global blue
global status
global framecount

set red 128
set green 128
set blue 128
set status 0
set framecount 0

# Construct the user interface:

init_tk

wm state . normal
wm title . "JTAG Demo"

frame .frmLayout -padx 5 -pady 5
pack .frmLayout -fill both -expand 1

button .btnConn -text "Connect..." -command "connect"
button .btnReset -text "Reset" -command "send_reset"

set  displayConnect "Not yet connected\nNo Interface\nNo Device"
label .lblConn -justify left -textvariable displayConnect

grid .btnConn -in .frmLayout -row 1 -column 1 -padx 5 -sticky ew
grid .btnReset -in .frmLayout -row 2 -column 1 -padx 5 -sticky ew
grid .lblConn -in .frmLayout -row 1 -column 2 -rowspan 2 -padx 5 -pady 5

label .lblred -anchor se -text "Red:"
label .lblgreen -anchor se -text "Green:"
label .lblblue -anchor se -text "Blue:"
label .lblframes -anchor se -text "Frame count:"
label .lblstat -anchor se -text "Status word:"

scale .sclgreen -from 0 -to 255 -resolution 1 -orient horizontal -variable green
scale .sclblue -from 0 -to 255 -resolution 1 -orient horizontal -variable blue
scale .sclred -from 0 -to 255 -resolution 1 -orient horizontal -variable red
label .lblframecount -anchor w -textvariable framecount
label .lblstatword -anchor w -textvariable status

grid .lblred -in .frmLayout -row 3 -column 1 -sticky nesw -pady 5
grid .lblgreen -in .frmLayout -row 4 -column 1 -sticky nesw -pady 5
grid .lblblue -in .frmLayout -row 5 -column 1 -sticky nesw -pady 5
grid .lblframes -in .frmLayout -row 6 -column 1 -sticky ew -pady 5
grid .lblstat -in .frmLayout -row 7 -column 1 -sticky ew -pady 5

grid .sclred -in .frmLayout -row 3 -column 2 -sticky ew -padx 5
grid .sclgreen -in .frmLayout -row 4 -column 2 -sticky ew -padx 5
grid .sclblue -in .frmLayout -row 5 -column 2 -sticky ew -padx 5
grid .lblframecount -in .frmLayout -row 6 -column 2 -sticky ew  -padx 5 -pady 5
grid .lblstatword -in .frmLayout -row 7 -column 2 -sticky ew -padx 5

update

# Find the USB Blaster - prompting the user if neccessary.
connect

# Begin the window update process
updatedisplay

# Wait for the user to close the window
tkwait window .

##################### End Code ########################################

