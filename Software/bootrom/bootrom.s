  include exec/types.i
  include exec/execbase.i
  include exec/alerts.i
  include exec/nodes.i
  include exec/resident.i
  include exec/memory.i
  include exec/lists.i
  include lvo/exec_lib.i
  include lvo/expansion_lib.i
  include libraries/configvars.i
  include hardware/cia.i
  include ../include/board.i

BonusEna  = $3000
BonusBase = $A00000
BonusPri  = 0
SysBase   = 4

CIAA = $BFE001

; Frame Pointer offsets
ExpansionBase = -4
FastRamBase   = -8
ControlBase   = -12
;

Start:  bra Init
        rts

RomTag:
        dc.w RTC_MATCHWORD
        dc.l RomTag
        dc.l EndCode
        dc.b (RTF_COLDSTART)
        dc.b 1
        dc.b NT_LIBRARY
        dc.b 0
        dc.l Name
        dc.l ID
        dc.l Init

; A2 = ExpansionBase, A6 = SysBase
Init:
          movem.l D2-D3/A2-A3/A6,-(SP)
          link.w  A5,#-16
          move.l  #0,FastRamBase(A5)
          move.l  #0,ExpansionBase(A5)
          movea.l SysBase,A6

          btst.b  #CIAB_GAMEPORT0,CIAA ; Exit if LMB pressed
          beq     exit

          moveq.l #0,D0
          lea     ExpansionName(PC),A1
          jsr     _LVOOpenLibrary(A6) 
          move.l  D0,ExpansionBase(A5)
          tst.l   D0
          beq     exit

FindRam:
          move.l D0,A6
          ;Check if board present
          move.l #0,A0
.loop:    move.l #MANUF_ID,D0
          move.l #PROD_ID_RAM,D1
          jsr    _LVOFindConfigDev(A6)
          tst.l  D0
          beq    exit

          move.l D0,A0
          btst   #CDB_SHUTUP,cd_Flags(A0)
          bne    .loop
          move.l cd_BoardAddr(A0),A0
          move.l A0,FastRamBase(A5)

FindCtrl:
          ;Check if board present
          move.l #0,A0
          move.l #MANUF_ID,D0
          move.l #PROD_ID_IDE,D1
          jsr    _LVOFindConfigDev(A6)
          tst.l  D0
          beq    exit

          move.l D0,A0
          move.l cd_BoardAddr(A0),A0
          add.l  #$8000,A0
          move.l A0,ControlBase(A5)

;; Sanity check, check to make sure that the memory block does not already exist
Sanity:   move.l SysBase,A6
          lea    MemList(A6),A2
          move.l LH_HEAD(A2),A2
.loop:    move.l MH_UPPER(A2),D0
          cmp.l  #BonusBase,D0             ; Is this blocks Upper limit lower than BonusBase?
          ble    .next                     ; If yes ignore it
          cmp.l  #(BonusBase+$1F0000),D0   ; Is it's upper-bound higher than Bonus Base's upper bound?
          bgt    .next                     ; Yes, ignore it
.found:   bra    exit                      ; No, if we got here the BonusRAM block fits inside the current block so we must not add it again
.next:    move.l LN_SUCC(A2),D0
          tst.l  D0                        ; End of the list?
          beq    .notfound                 ; No matching block found, go ahead and add the Bonus RAM block
          move.l D0,A2
          bra.s  .loop
.notfound

;; Turn on BonusRAM region
Enable:   move.l ControlBase(A5),A0
          or.b   #$20,(A0)

;; Get the Bonus RAM size with a simple address test
Size:     moveq.l #31,D3               ; Loop 31 times - A00000-BEFFFF
          move.l  #BonusBase+$B00,A2   ; We poke at Addr+$B00 because this address will not trash CIA registers if our overlay is not active/working
          moveq.l #0,D2                ; BonusRAM Size
          bra.s   .start

.loop:    move.w D1,(A2)               ; Restore saved value
          add.l  #$10000,A2            ; Increment test address by 64K
          add.l  #$10000,D2            ; Increase BonusRAM size by 64K
.start:   move.w (A2),D1               ; Save value at address
          move.l A2,D0
          lsr.l  #8,D0
          move.w D0,(A2)               ; Store upper address bits
          nop
          nop
          cmp.w  (A2),D0               ; Compare memory value
          bne.s  .done                 ; Value didn't match
          dbra   D3,.loop
.done:    move.w D1,(A2)               ; Restore last saved value
          tst.l  D2                    ; Did we find any RAM?
          beq    exit

;; Attempt to merge Z2 Fast with BonusRAM
;; A2 = Pointer to board/mem header
;; A1 = Pointer to Chunk
;; D2 = BonusSize
Merge:    move.l #0,D3
          move.l FastRamBase(A5),A2
          move.l MH_UPPER(A2),D0    ; Check if board neighbors BonusRAM
          cmp.l  #BonusBase,D0
          bne.s  .NewBrd            ; Nope

          movea.l SysBase,A6
          jsr     _LVOForbid(A6)

          lea    MH_FIRST(A2),A3
.walk:    move.l MC_NEXT(A3),D0     ; Skip through mem chunks until we get to the end
          beq.s  .last
          move.l MC_NEXT(A3),A3
          bra.s  .walk

.last:    move.l MC_BYTES(A3),D1    ; Add Chunk size to chunk address, see if chunk is at the end
          move.l A3,D0
          add.l  D0,D1
          cmp.l  #BonusBase,D1
          bne.s  .MakeNew
          move.l MC_BYTES(A3),D1    ; Yes it is, increase the chunk size by BonusSize
          add.l  D2,D1
          move.l D1,MC_BYTES(A3)    ; And store it back
          bra.s  .FixMH

.MakeNew: move.l #BonusBase,D0      ; No free chunk at the end of Z2 Board, Add a new chunk
          move.l D0,MC_NEXT(A3)
          move.l #BonusBase,A3
          move.l #0,MC_NEXT(A3)
          move.l D2,MC_BYTES(A3) 

;; Now fixup the MemHeader to reflect the new memory size
.FixMH:   move.l #BonusBase,D0      ; Add BonusSize to BonusBase
          add.l  D2,D0
          move.l D0,MH_UPPER(A2)    ; Store it as the MemHeader Upper limit
          move.l MH_FREE(A2),D0     ; Add BonusSize to MemFree
          add.l  D2,D0
          move.l D0,MH_FREE(A2)     ; Save back to MemFree
          move.l FastRamBase(A5),A2
          lea    GottaGoFast(PC),A3
          move.l A3,LN_NAME(A2)
          jsr    _LVOPermit(A6)
          bra.s  .done

;; Couldn't expand an existing block so we just create a whole new one
.NewBrd:  move.l SysBase,A6
          move.l D2,D0
          move.l #MEMF_FAST|MEMF_PUBLIC|MEMF_24BITDMA,D1
          move.l #BonusPri,D2
          move.l #BonusBase,A0
          lea    GottaGoFast(PC),A1
          jsr    _LVOAddMemList(A6)
.done:

;; Kickstart versions below 2.0 give Slow RAM the same priority as Fast
;; So take the opportunity to change the priority to -5
FixPrio:
          move.l SysBase,A6       ; Skip if running Kick 2 and up
          cmp.l  #36,SoftVer(A6)
          bge.s  .end
          lea    MemList(A6),A2
          move.l LH_HEAD(A2),A3
.loop:    cmp.l  #$C00000,MH_LOWER(A3) ; Memory Node is Ranger?
          blt    .next
          cmp.l  #$DEFFFF,MH_UPPER(A3)
          bgt    .next
          bra.s  .found

.next     move.l LN_SUCC(A3),D0        ; Keep looking
          tst.l  D0
          beq.s  .end
          move.l D0,A3
          bra.s .loop

.found    move.b LN_PRI(A3),D0         ; If the priority is non-zero then don't change it
          tst.b  D0
          bne.s  .end

          jsr    _LVOForbid(A6)

          move.l A3,A1                 ; Remove and Re-enqueue and move it to the right position in the list
          jsr    _LVORemove(A6)

          move.l A3,A1
          move.l A2,A0
          move.b #-5,LN_PRI(A3)
          jsr    _LVOEnqueue(A6)

          jsr    _LVOPermit(A6)
.end:

exit:     move.l ExpansionBase(A5),D0
          tst.l  D0
          beq    .noexp
          move.l SysBase,A6
          move.l D0,A1
          jsr    _LVOCloseLibrary(A6)

.noexp:   unlk    A5
          movem.l (SP)+,D2-D3/A2-A3/A6
          moveq.l #0,D0
          rts

GottaGoFast: dc.b "GottaGoFast!",0,0
        cnop 0,4
ExpansionName: dc.b "expansion.library",0
Name:          dc.b "RIDE.library",0
ID:            dc.b "RIDE Support",0

EndCode:
