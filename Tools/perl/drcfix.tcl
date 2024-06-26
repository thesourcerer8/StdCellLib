proc redirect_variable {varname cmd} {
    rename puts ::tcl::orig::puts
    global __puts_redirect
    set __puts_redirect {}
    proc puts args {
        global __puts_redirect
        set __puts_redirect [concat $__puts_redirect [lindex $args end]]
        set args [lreplace $args end end]
        if {[lsearch -regexp $args {^-nonewline}]<0} {
            set __puts_redirect "$__puts_redirect\n"
        }
        return
    }
    uplevel $cmd
    upvar $varname destination
    set destination $__puts_redirect
    unset __puts_redirect
    rename puts {}
    rename ::tcl::orig::puts puts
}

proc getCheckpoint {} {
   #save checkpoint
   #return
   redirect_variable undostack {undo print 10}
   #puts "Undostack: $undostack"
   #head=0xd620c840	tail=0xd5b648a0	cur=0xd5b648a0
   regexp {cur=(0x\w+)} $undostack full cur
   #puts "cur: $cur"
   undo print 20
   return $cur
}

proc undoToCheckpoint {checkpoint} {
   #load checkpoint
   #return
   redirect_variable undostack {undo print 10}
   regexp {cur=(0x\w+)} $undostack full cur
   regexp {head=(0x\w+)} $undostack full head
   #undo print 20
   if {$head ne 0x0} {
     if {$checkpoint == 0x0} {
       set checkpoint $head
     }
     set tries 0
     while {$cur ne $checkpoint && $cur ne 0x0 && $tries < 200 } {
       #puts "Undo ..."
       undo
       #undo print 20
       redirect_variable undostack {undo print 10}
       regexp {cur=(0x\w+)} $undostack full cur
       incr tries
     }
     if {$tries > 180} {
       puts "WARNING: $tries tries were tried, this is strange"
       #undo print 20
     }
   }
}

#getCheckpoint

proc fix_drc {} {
   puts "select top cell"
   select top cell
   puts "drc style $DRCSTYLE"
   drc style $DRCSTYLE
   puts "drc on"
   drc on
   puts "drc check"
   drc check
   puts "drc catchup"
   drc catchup
   puts "drc listall catchup"
   drc listall catchup
   puts "drc find"
   drc find
   puts "drc check"
   drc check
   puts "drc catchup"
   drc catchup
   set ndebugfile 1
   puts "Redirecting Variable"
   redirect_variable drccount {drc count total}
   puts "Setting checkpoint"
   set checkpoint [getCheckpoint]
   puts "Checkpoint: $checkpoint"
   set nFixed 0
   puts "DRC count: $drccount"
   set drcc [string trim [string map {"Total DRC errors found: " ""} $drccount] ]
   if {$drcc == 0} return
   set yReposition {0 2 -2 9 -9}

   foreach yRepo $yReposition {
   puts "Trying Reposition $yRepo"
   set nRounds $drcc
   puts $drccount
   #puts $drcc
   for {set i 0} {$i <= $nRounds + 10 } {incr i} {
     puts "I am inside the first loop: $i"
     if {$drcc > 0} {
       redirect_variable drcresult {drc find}
       puts "move up $yRepo"
       move up $yRepo
       puts $drcresult
       if {[string first "\[" $drcresult] != -1} {
         regexp {\[(erase|paint) ([^\]]+)\]} $drcresult full drccommand layernames
         if {$yRepo != 0 } { 
           puts "This is an addition for Sky130: We have some 20nm wide inter-net spacings that we need to paint on locali, so we reposition the box and try to paint on locali"
           set drccommand "paint" 
	   set layernames "locali"
         }
	 if {$drccommand == "erase" } {
	   redirect_variable bbox {box}
	   #lambda:       44 x 10      (     0,  309  ), (    44,  319  )  440 
	   #lambda:   2.00 x 8.50    ( 463.50,  217.50), ( 465.50,  226.00) 17.00
	   puts "BOX: $bbox"
	   regexp {lambda:\s*\d+\.?\d* x \d+\.?\d*\s+\([^\)]*\), \(\s*(\d+\.?\d*),\s*(\d+\.?\d*)} $bbox full boxX boxY
           puts "Bounding box for erase: $boxX $boxY"
           if {$boxY >= 309 } { 
             puts "This is an addition for Sky130: We do not want to erase the power rails, so we skip ignore rules outside the core of the cell"
	     set layernames "" 
	   }
	 }
         foreach drcparts [split $layernames ","] {
           puts "Trying layers $drcparts"
           foreach layername [split $drcparts " "] {
             puts "$drccommand $layername"
	     $drccommand $layername
	     puts "done with this layer."
	   }
	   # save "$OUTPUT.try.$ndebugfile"
	   incr ndebugfile
           drc check
           drc catchup
           redirect_variable drccountnew {drc count total}
           set drccn [string trim [string map {"Total DRC errors found: " ""} $drccountnew] ]
	   if {$drccn == 0} {
             puts "We have fixed all issues, no need to try more"
             save $OUTPUT
             puts "File $OUTPUT saved."
             quit -noprompt
	   }
           if {$drccn < $drcc} {
             puts "Hoory, we fixed a DRC issue"
             incr nFixed 
             set drcc $drccn
             set checkpoint [getCheckpoint]
             puts "New Checkpoint: $checkpoint"
           } else {
             puts "Trying to fix this DRC issue did not reduce the number of DRC issues ($drccn vs. $drcc) so we undo and try something else"
	     undoToCheckpoint $checkpoint
	     #foreach layername [split $drcparts " "] {
	     #  puts "Undoing $layername"
	     #  #erase $layername
	     #  undo
	     #}
           }
	 }
       }
      }
     }
   }

   if {$nFixed >0} {
      puts "We have fixed some issues, $drccn issues are remaining, we give up and save the file now."
      save $OUTPUT
      puts "File $OUTPUT saved."
   } else {
      puts "We could not fix any issues."
   }
}   
puts "Trying to FIX some DRC issues"
load $MAG
puts "Calling fix_drc"
fix_drc
puts "Done trying to FIX some DRC issues"
quit -noprompt
