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
	global cutoff
	global ksval
	global ksperiod
	global status
	global framecount

	if {$connected} {
		if [ vjtag::usbblaster_open ] {
			# CMD 0, set RGB
			vjtag::send [expr ($red << 16) + ($green << 8) + $blue ]
			# CMD 1, set filter cutoff
			vjtag::send [expr (1<<24) + $cutoff ]
			# CMD 2, set Karplus-Strong delay
			vjtag::send [expr (2<<24) + $ksval ]
			# CMD 3, set Karplus-Strong period
			vjtag::send [expr (3<<24) + $ksperiod ]
			# CMD 0xfe, report
			vjtag::send [expr (0xfe << 24) ]
			set framecount [vjtag::recv_blocking]
			set status [vjtag::dec2bin [vjtag::recv_blocking] 32]
			# A dummy read to clear the FIFO if sync was lost and it contains stale data.
			set resync [vjtag::recv] 
		}
		vjtag::usbblaster_close
	}
	after 50 updatedisplay
}

proc send_chirp {} {
	global connected

	if {$connected} {
		if [ vjtag::usbblaster_open ] {
			# CMD 0xfd, send chirp
			vjtag::send [expr (0xfd << 24) ]
		}
		vjtag::usbblaster_close
	}
}

proc send_reset {} {
	global connected
	set contmp $connected;
	set connected 0
	if {$contmp} {
		if [ vjtag::usbblaster_open] {
			vjtag::send [expr (255 << 24)]
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
set cutoff 512
set ksval 96
set ksperiod 96
set status 0
set framecount 0

# Construct the user interface:

init_tk

wm state . normal
wm title . "JTAG Demo"

# Connection buttons
frame .frmConnection -relief sunken -borderwidth 2 -padx 5 -pady 5
pack .frmConnection -fill both -expand 1
grid columnconfigure .frmConnection 0 -weight 0
grid columnconfigure .frmConnection 1 -weight 1

button .btnConn -text "Connect..." -command "connect"
button .btnReset -text "Reset" -command "send_reset"

set  displayConnect "Not yet connected\nNo Interface\nNo Device"
label .lblConn -justify left -textvariable displayConnect

grid .btnConn -in .frmConnection -row 0 -column 0 -padx 5 -sticky ew
grid .lblConn -in .frmConnection -row 0 -column 1 -rowspan 2 -padx 5 -pady 5
grid .btnReset -in .frmConnection -row 1 -column 0 -padx 5 -sticky ew


# Red / Green / Blue sliders

frame .frmRGB -relief sunken -borderwidth 2 -padx 5 -pady 5
pack .frmRGB -fill both -expand yes
grid columnconfigure .frmRGB 0 -weight 0
grid columnconfigure .frmRGB 1 -weight 1

label .lblred -anchor se -text "Red:"
label .lblgreen -anchor se -text "Green:"
label .lblblue -anchor se -text "Blue:"

scale .sclred -from 0 -to 255 -resolution 1 -orient horizontal -variable red
scale .sclgreen -from 0 -to 255 -resolution 1 -orient horizontal -variable green
scale .sclblue -from 0 -to 255 -resolution 1 -orient horizontal -variable blue

grid .lblred -in .frmRGB -row 3 -column 0 -sticky nesw -pady 5
grid .lblgreen -in .frmRGB -row 4 -column 0 -sticky nesw -pady 5
grid .lblblue -in .frmRGB -row 5 -column 0 -sticky nesw -pady 5

grid .sclred -in .frmRGB -row 3 -column 1 -sticky ew -padx 5
grid .sclgreen -in .frmRGB -row 4 -column 1 -sticky ew -padx 5
grid .sclblue -in .frmRGB -row 5 -column 1 -sticky ew -padx 5

# Karplus-Strong synth sliders

frame .frmSynth -relief sunken -borderwidth 2 -padx 5 -pady 5
pack .frmSynth -fill both -expand 1
grid columnconfigure .frmSynth 0 -weight 0
grid columnconfigure .frmSynth 1 -weight 1

label .lblcutoff -anchor se -text "Noise filter period:"
label .lblksval -anchor se -text "Karplus-Strong period:"
label .lblksper -anchor se -text "KS Filter period:"

scale .sclcutoff -from 1 -to 4095 -resolution 1 -orient horizontal -variable cutoff
scale .sclksval -from 1 -to 1024 -resolution 1 -orient horizontal -variable ksval
scale .sclksper -from 1 -to 1024 -resolution 1 -orient horizontal -variable ksperiod
button .btnInitiate -text "Initiate sound" -command "send_chirp"

grid .lblcutoff -in .frmSynth -row 6 -column 0 -sticky nesw -pady 5
grid .lblksval -in .frmSynth -row 7 -column 0 -sticky nesw -pady 5
grid .lblksper -in .frmSynth -row 8 -column 0 -sticky nesw -pady 5
grid .btnInitiate -in .frmSynth -row 9 -column 0 -columnspan 2 -sticky nesw -pady 5

grid .sclcutoff -in .frmSynth -row 6 -column 1 -sticky ew -padx 5
grid .sclksval -in .frmSynth -row 7 -column 1 -sticky ew -padx 5
grid .sclksper -in .frmSynth -row 8 -column 1 -sticky ew -padx 5


# Frame / Status display

frame .frmStatus -relief sunken -borderwidth 2 -padx 5 -pady 5
pack .frmStatus -fill both -expand true
grid columnconfigure .frmStatus 0 -weight 0
grid columnconfigure .frmStatus 1 -weight 1

label .lblframes -anchor se -text "Frame count:"
label .lblstat -anchor se -text "Status word:"
label .lblframecount -anchor w -textvariable framecount
label .lblstatword -anchor w -textvariable status

grid .lblframes -in .frmStatus -row 10 -column 0 -sticky ew -pady 5
grid .lblstat -in .frmStatus -row 11 -column 0 -sticky ew -pady 5
grid .lblframecount -in .frmStatus -row 10 -column 1 -sticky ew  -padx 5 -pady 5
grid .lblstatword -in .frmStatus -row 11 -column 1 -sticky ew -padx 5

update

# Find the USB Blaster - prompting the user if neccessary.
connect

# Begin the window update process
updatedisplay

# Wait for the user to close the window
tkwait window .

##################### End Code ########################################

