##  LipidBuilder
##
## Laboratory for Biomolecular Modeling, EPFL
## 2013 Version 2.0
## Authors
##   -Thomas Lemmin
##   -Christophe Bovigny
##   -Laurent Fasnacht
## Update 2014 v 2.1
##   -Thomas Lemmin


package provide lipidbuilder 2.1


package require topology_reader
package require topology_writer

package require smiles_parser
package require smile2topology
package require psfgen

package require http
 
namespace eval ::lipidBuilder:: {
  namespace export lipidbuilder
  namespace export lipidbuilder-parse

  #define package variables

  #FIXME: AUTO ID WHAT MOLECULE YOU"RE USING
  #Default force field parameters:
  variable debug
  variable nsel
  variable sel1 
  variable sel2
  variable sel3
  variable sel4
  variable gui 0
  variable LipidBuilder [file dirname [file normalize [info script]]]
  variable resname
  
  variable LipidBuilderLibraryURL "http://lipidbuilder.epfl.ch/lipidlibrary/index.txt"
  variable tmpsubmenu 0
  variable categories [list "phospholipid" "sphingolipid" "glycolipid" "triglyceride"]
  variable defaultCategory 0
  variable category
  variable heads [list "phospholipid" "PA PC PG PE PS" "sphingolipid" "PC PE" "glycolipid" "PI PD PG" "triglyceride" "TG"]
  variable defaultHeads
  variable defaultHead 0 
  variable head
  set debug 0
#  set currentMol $nullMolString
  variable molMenuText
#  trace add variable [namespace current]::currentMol write ::lipidBuilder::molmenuaux 

}

proc ::lipidBuilder::lipidbuilder_usage {} {
  puts "lipidBuilder) Usage: lipidbuilder ..."
  puts "lipidBuilder) Options: "
  puts "lipidBuilder) 	    headgroup"
  puts "lipidBuilder) 	    resname"
  puts "lipidBuilder) 	    tails"
  puts "lipidBuilder) 	    outDir"
  puts "Example:"
  puts "lipidbuilder PC POPC {{CCCCCCC/C=C\\CCCCCCCC} {CCCCCCCCCCCCCCC}} .
  error ""
}

proc ::lipidBuilder::lipidbuilder { head resname tails outdir } {
  #This is the frontend text proc for lipidbuilder; it will produce all the
  #
  variable LipidBuilder

  set error 0
  set errorMsg [list]
      if { $resname == "" || [string length $resname] > 4 } {
        puts "The resname should be defined and is limited to 4 characters\n"
        set error 1
      }
      #Tails
      if {$head == "CD" || $head == "CP"} {
        if {[llength $tails]!= 4} {
                puts "All four tails have to be defined for cardiolipin\n"
                set error 1;
        }
      } else {
        if {[llength $tails]!= 2} {
                puts "Two tails have to be defined.\n"
                set error 1;
        }
      }
      set count 1
      foreach t $tails {
              if {![checkTail $t]} {
                puts "Invalid SMILE for tail $count. The SMILE may only contain C|=|#|/|\\ or a cyclopropane. \n"
                set error 1;
               }
        incr count
      }
        if {$error == 0} {
                if {[createTopology $head $tails $resname $outdir] == -1} {
                	puts "Unable to create lipid due to unknown atom type"
                	return 0
                }
                createTemplate $outdir/${resname}.top $head $outdir
                return 1
        } else {
		puts "Unable to create lipid due to errors"
                return 0
        }
}

proc ::lipidBuilder::gui_init_defaults {} {
  variable w
  variable tail1
  variable tail2
  variable tail3
  variable tail4
  variable LipidBuilder 
  variable resname
  variable categories
  variable defaultCategory [lindex $categories 0]
  variable category $defaultCategory
  variable heads
  array set aheads $heads
  variable defaultHeads $aheads($defaultCategory)
  variable defaultHead [lindex $defaultHeads  0]
  variable head $defaultHead

}

proc ::lipidBuilder::loadLibrary { token } {
  variable w
  set data [::http::data $token]
  
  ::lipidBuilder::parseData $w.menubar.loadlibrary.menu $data
}

proc ::lipidBuilder::parseData { m data } {
  set buf ""
  set basews -1
  
  if {$data == ""} {
    return
  }
  
  foreach line [split $data "\n"] {
    set linews [string length [lindex [regexp -inline -- {^(\s*).*$} $line] 1]]
    set linetrimmed [string range $line $linews end]
    set linebtrimmed [string range $line $basews end]
    
    if {$buf == ""} {
      set basews $linews
      set buf $linetrimmed
    } else {
      if {$linews > $basews} {
        set buf "${buf}\n${linebtrimmed}"
      } else {
        #Add data
        ::lipidBuilder::addMenuForData $m $buf
        set basews $linews
        set buf $linetrimmed
      }
    }
  }
  
  ::lipidBuilder::addMenuForData $m $buf
}

proc ::lipidBuilder::addMenuForData { m data } {
  if {$data == ""} {
    return
  }
  set lines [split $data "\n"]
  if {[llength $lines] > 1} {
    ::lipidBuilder::addMenuSubMenuForData $m [lindex $lines 0] [join [lrange $lines 1 end] "\n"]
  } else {
    set parts [split $data "|"]
    ::lipidBuilder::addMenuEntryForData $m [lindex $parts 0] [join [lrange $parts 1 end] "|"]
  }
}

proc ::lipidBuilder::addMenuSubMenuForData { m title data } {
  #Counter
  variable tmpsubmenu
  incr tmpsubmenu
  
  variable w
  
  $m add cascade -label $title -menu  $w.menubar.loadlibrary.menu.$tmpsubmenu
  menu $w.menubar.loadlibrary.menu.$tmpsubmenu -tearoff no
  
  ::lipidBuilder::parseData $w.menubar.loadlibrary.menu.$tmpsubmenu $data
  
}

proc ::lipidBuilder::addMenuEntryForData { m title url } {
  $m add command -label $title -command "::lipidBuilder::fetchSetTemplate $url"
}

proc ::lipidBuilder::fetchSetTemplate { url } {
  ::http::geturl $url -command ::lipidBuilder::setTemplateFromHttp
}

proc ::lipidBuilder::setTemplateFromHttp { token } {
  set lines [split [::http::data $token] "\n"]
  
  set ::lipidBuilder::head [lindex $lines 0]
  set ::lipidBuilder::resname [lindex $lines 1]
  set ::lipidBuilder::tail1 [lindex $lines 2]
  set ::lipidBuilder::tail2 [lindex $lines 3]
  set ::lipidBuilder::tail3 [lindex $lines 4]
  set ::lipidBuilder::tail4 [lindex $lines 5]
}

proc ::lipidBuilder::updateLipidBuilder {} {

}

proc ::lipidBuilder::parseHeads {} {
  variable categories
  variable heads
  variable nbrTails
  set f [open "${LipidBuilder}/heads.dat" r]
  set data [read $f]
  close $f
  foreach d $data {
    
  }
  return 1
}

proc ::lipidBuilder::changeHeads args {
  variable w
  variable category
  variable heads
  array set aheads $heads
  variable defaultHeads $aheads($category)
  variable defaultHead [lindex $defaultHeads  0]
  variable head $defaultHead
  $w.headname.menu delete 0 end
  foreach h $defaultHeads {
	  $w.headname.menu add radiobutton -variable [namespace current]::head -label $h  
  }
  #TODO update number of tails
}

proc ::lipidBuilder::lipidbuilder_mainwin {{defaults 1}} {
  variable w
  variable tail1
  variable tail2
  variable tail3
  variable tail4
  variable debug
  variable keepforce
  variable molMenuText
  variable guiOutdir [pwd]
  variable defaultHead 
  variable head $defaultHead
  variable defaultHeads
  variable LipidBuilderLibraryURL
  variable categories
  variable category
  if {$defaults == 1} {
    gui_init_defaults
   
   } 

if {[llength [trace info variable [namespace current]::head]] == 0} {
    trace add variable [namespace current]::head write ::lipidBuilder::enable_tails
  }


#De-minimize if the window is already running
  if { [winfo exists .lipidbuilder] } {
    wm deiconify $w
    return
  }


  set w [toplevel ".lipidbuilder"]
  wm title $w "lipidBuilder"
  wm resizable $w yes yes
 
  set row 0

  #Add a menubar
  frame $w.menubar -relief raised -bd 2
  grid  $w.menubar -padx 1 -column 0 -columnspan 8 -row $row -sticky ew
  menubutton $w.menubar.help -text "Help" -underline 0 \
    -menu $w.menubar.help.menu
  $w.menubar.help config -width 5 
  pack $w.menubar.help -side right
 
  ## help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About lipidBuilder" \
              -message "This plugin was developped by the Laboratory for Biomolecular Modeling (lbm.epfl.ch) 2013.

Authors : 
Thomas Lemmin
Christophe Bovigny
Laurent Fasnacht"}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url http://lipidbuilder.epfl.ch"
    
  #Load from library menu
  menubutton $w.menubar.loadlibrary -text "Library" -underline 0 \
    -menu $w.menubar.loadlibrary.menu
  $w.menubar.loadlibrary config -width 5 
  pack $w.menubar.loadlibrary -side left
  
  menu $w.menubar.loadlibrary.menu -tearoff no
  
  catch {::http::geturl $LipidBuilderLibraryURL -command ::lipidBuilder::loadLibrary}

  incr row

  #Selection of lipid head group 
  grid [label $w.categorylabel -text  "Lipid category: " ] \
    -row $row -column 0 -columnspan 1 -sticky w 
  eval "tk_optionMenu \$w.categoryname [namespace current]::category $categories"
  trace variable [namespace current]::category w [namespace current]::changeHeads
  #pack $w.categoryname
  grid $w.categoryname -row $row -column 1 -columnspan 1 -sticky ew
  grid [button $w.helbutton -text "?" -command "vmd_open_url http://lipidbuilder.epfl.ch" ] \
    -row $row -column 2  -sticky w


  incr row

  grid [label $w.headlabel -text  "Lipid headgroup: " ] \
    -row $row -column 0 -columnspan 1 -sticky w 
  eval "tk_optionMenu \$w.headname [namespace current]::head $defaultHeads"
  grid $w.headname -row $row -column 1 -columnspan 1 -sticky ew
  incr row

  grid [label $w.resnamelabel -text "Resname : "] \
    -row $row -column 0 -sticky w
  grid [entry $w.resname -width 4 \
    -textvariable [namespace current]::resname] \
    -row $row -column 1 -columnspan 1 -sticky ew
  incr row


  grid [label $w.textlabel -text "SMILE of hydrocarbon tails: "] \
    -row $row -column 0 -columnspan 6 -sticky w

  incr row

  #Input for selection #1
  grid [label $w.sel1label -text "Tail 1: "] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel1 -width 60 \
    -textvariable [namespace current]::tail1] \
    -row $row -column 1 -columnspan 6 -sticky ew
  incr row

  #Input for selection #2
  grid [label $w.sel2label -text "Tail 2: "] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel2 -width 60 \
    -textvariable [namespace current]::tail2] \
    -row $row -column 1 -columnspan 6 -sticky ew
  incr row

  #Input for selection #3
  grid [label $w.sel3label -text "Tail 3 (opt): " ] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel3 -width 60 \
    -textvariable [namespace current]::tail3 ] \
    -row $row -column 1 -columnspan 6 -sticky ew  
  incr row
  #Input for selection #4
  grid [label $w.sel4label -text "Tail 4 (opt): " ] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel4 -width 60 \
    -textvariable [namespace current]::tail4 ] \
    -row $row -column 1 -columnspan 6 -sticky ew 
  incr row

  grid [label $w.title -text "Output directory :"] \
    -row $row -column 0  -columnspan 1 -sticky w
  grid [entry $w.entry -textvariable [namespace current]::guiOutdir \
     -width 45 -relief sunken -justify left -state readonly] \
    -row $row -column 1 -columnspan 4 -sticky e
 grid [button $w.button -text "Choose" -command "::lipidBuilder::getoutdir"] \
    -row $row -column 6 -columnspan 5 -sticky e
 
 incr row   

  #Create lipid top pdb and psf

 grid [button $w.gobutton -text "Create Lipid" -command "::lipidBuilder::buildAndView" ] \
    -row $row -column 0 -columnspan 8 -sticky nsew

 incr row
 ::lipidBuilder::enable_tails
}


# This gets called by VMD the first time the menu is opened.
proc lipidbuilder_tk {} {
  ::lipidBuilder::lipidbuilder_mainwin
  return $::lipidBuilder::w
}

#This proc put the two last tail input offline

proc ::lipidBuilder::enable_tails {args} {
  variable w
  variable head
 

  # Disable the prefix file field
 if {$head == "CD" || $head == "CP"} {
      if {[winfo exists $w.sel3label]} {
      $w.sel3label configure -state normal
      $w.sel3 configure -state normal
      $w.sel4label configure -state normal
      $w.sel4 configure -state normal
}
  } else {
  if {[winfo exists $w.sel3label]} {
  $w.sel3label configure -state disabled
  $w.sel3 configure -state disabled
  $w.sel4label configure -state disabled
  $w.sel4 configure -state disabled 
}
}
}
proc ::lipidBuilder::getoutdir {} {
  variable guiOutdir

  set newdir [tk_chooseDirectory \
    -title "Choose output directory" \
    -initialdir $guiOutdir -mustexist true]

  if {[string length $newdir] > 0} {
    set guiOutdir $newdir
  }
}


proc ::lipidBuilder::buildAndView {} {
	variable guiOutdir
	variable resname
	mol delete all
	if { [checkAndBuild] } {
		mol new ${guiOutdir}/${resname}.psf
		mol addfile ${guiOutdir}/${resname}.pdb
	}
}

proc ::lipidBuilder::checkAndBuild {} {
  variable guiOutdir
  variable head
  variable resname
  variable tail1
  variable tail2
  variable tail3
  variable tail4

  set error 0
  set errorMsg [list]
      if { $resname == "" || [string length $resname] > 4 } {
	lappend errorMsg "- The resname should be defined and is limited to 4 characters\n"
	set error 1
      }
      #Tails
      if {$head == "CD" || $head == "CP"} {
      	set tails [concat $tail1 $tail2 $tail3 $tail4]
	if {[llength $tails]!= 4} {
		lappend errorMsg "- All four tails have to be defined for cardiolipin\n"
                set error 1;
	}
      } else {
      	set tails [concat $tail1 $tail2]
	if {[llength $tails]!= 2} {
		lappend errorMsg "- Both tails have to be defined.\n"
                set error 1;
	}
      }
      set count 1
      foreach t $tails {
	      if {![checkTail $t]} {
         	lappend errorMsg "- Invalid SMILE for tail $count. The SMILE should be at least 2 atom long and may only contain C|=|#|/|\\ or a cyclopropane.  \n"
		set error 1;
	       }
	incr count
      }
	if {$error == 0} {
		if {[createTopology $head $tails $resname $guiOutdir] == -1} {
                	onError "Unable to create lipid due to unknown atom type. \n Please check smile sequence."
                	return 0
       }
	 	createTemplate $guiOutdir/${resname}.top $head $guiOutdir
		return 1 
	} else {
		onError [join $errorMsg ""]
		return 0
	}
}

proc ::lipidBuilder::checkTail {SMILE} {
        set lsmile [split $SMILE ""]
        if {[llength $lsmile] < 2} {
        	puts "The SMILE should be at least 2 atoms long"
        	return 0
    	}
        if {[lsearch -not -regexp $lsmile {C|=|#|\\|/|[0-9]|(|)}]!=-1} {
                puts "Invalid SMILE for alkyl chain. The SMILE may only contain C|=|#|/|\\|(|). \n"
                return 0
        }
        set cycles [lsearch -all -regexp $lsmile {[0-9]}]
        if {[expr ([llength $cycles] % 2)] != 0} {
                puts "Branch in SMILE. Only cyclopropane is allowed."
                return 0
        } else {
                foreach {b e} $cycles {
                        if {[expr $e-$b]!=3} {
                                puts "Unvalid cycle. Only cyclopropane is allowed (e.g. C1CC1)"
                        #        return 0
                        }
                }
        }

        return 1

}

###########################################################################
#
#               Builders
#
###########################################################################

 
proc ::lipidBuilder::createTopology {head tails resname pathOut} {
	variable LipidBuilder
    ::topology_writer::init
    ::topology_reader::init
    ::smile2topology::read_ICparameters "$LipidBuilder/hydrocarbon_topology.dat"
	::topology_reader::read_topology  $LipidBuilder/topology/lipid_masses.top
	if {[file exists  $LipidBuilder/topology/${head}.top]} {
		::topology_reader::read_topology  $LipidBuilder/topology/${head}.top
	} else {
		puts "Unknown lipid head group ${head}"
		puts "Head groups should be PA PC PE PG PS CD or CP"
	}
	set tails [string map {\\ \\\\} $tails]
	#load head group topology in writer
	::topology_writer::concat_top [lindex $::topology_reader::atomtopology 1] [lindex $::topology_reader::bonds 1]  [lindex $::topology_reader::ICs 1]
	set H [list {} {} {R S T} {X Y Z} {U V W} {A B C} ]
        set index 2
        foreach tail $tails {
        		set data [::smiles_parser::smiles_parse $tail]
        		set structure [::smiles_parser::flatten $data]
        		::smile2topology::initsmile
        		::smile2topology::assign_atom_keys $structure
				if {[::smile2topology::assign_atoms C${index} [lindex $H $index]] == -1} {
					return -1
				}
				::smile2topology::assign_bonds $structure
				::smile2topology::set_ICs $structure
				#link to head group
				::topology_writer::set_connectivity_IC  [::smile2topology::get_linker] [lindex $::topology_reader::IC_linker 1]
				::topology_writer::set_connectivity_bonds [::smile2topology::get_linker] [lindex $::topology_reader::bonds_linker 1]
				::topology_writer::set_improper [::smile2topology::get_linker] [lindex $::topology_reader::limpropertopology 1]
				#load tail topology in writer
				::topology_writer::concat_top [::smile2topology::get_atoms] [::smile2topology::get_bonds] $::smile2topology::ICs
				
                incr index
       	}
       	
	::topology_writer::set_masses $::topology_reader::masses
	#HERE LAST EDIT
	::topology_writer::write_topology "$pathOut/${resname}.top" $resname
}


proc ::lipidBuilder::createTemplate {topology head pathOut} {
	variable LipidBuilder
	::topology_reader::init
	::topology_reader::read_topology $topology
	set resname [lindex $::topology_reader::atomtopology 0]
	get_template $LipidBuilder/heads/${head}.pdb $resname L1 $pathOut
	build_template $resname  $topology L1 $pathOut
}

proc ::lipidBuilder::build_template {resname topology segname pathOut} {
	topology $topology
        segment $segname  {pdb $pathOut/${resname}.pdb}
        coordpdb $pathOut/${resname}.pdb
        guesscoord
        writepdb $pathOut/${resname}.pdb
        writepsf $pathOut/${resname}.psf
	psfcontext reset
}


proc ::lipidBuilder::get_template {head resname segname pathOut} {
	mol new $head
        set h [atomselect top all]
        $h set resname $resname
	$h set segname $segname
        $h writepdb $pathOut/${resname}.pdb
        mol delete all
}


###########################################################################
#
#		Error messages
#
###########################################################################
proc onError {Msg} {
    tk_messageBox -type ok -icon error -title Error  \
    -message $Msg 
}

proc onWarn {Msg} {
    tk_messageBox -type ok -icon warning -title Warning \
    -message $Msg
}

proc onQuest {Msg} {
    tk_messageBox -type ok -icon question -title Question \
    -message $Msg
}

proc onInfo {Msg} {
    tk_messageBox -type ok -icon info -title Information \
    -message $Msg
}
proc onHead {Msg} {
 tk_messageBox -type ok -icon error -title Error  \
    -message $Msg
}
