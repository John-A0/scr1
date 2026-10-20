# GTKWave script for lab 3 (variant 5): loads the signals of the xor analysis.
# Run from the folder with simx.vcd:
#   gtkwave simx.vcd -S xor_signals.tcl
set P TOP.scr1_top_tb_ahb.i_top.i_core_top.i_pipe_top
set sigs [list \
    $P.clk \
    "$P.curr_pc\[31:0\]" \
    $P.pipe2imem_req_o \
    "$P.pipe2imem_addr_o\[31:0\]" \
    "$P.imem2pipe_resp_i\[1:0\]" \
    "$P.imem2pipe_rdata_i\[31:0\]" \
    $P.instret_nexc ]
gtkwave::addSignalsFromList $sigs
# the first xor (pc = 0x2b0) is executed at t = 482 ps, it arrives on imem_rdata at 462 ps
gtkwave::setMarker 482
catch { gtkwave::setZoomRangeTimes 422 522 }
