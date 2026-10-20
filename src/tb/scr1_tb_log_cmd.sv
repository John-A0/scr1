/// @file       <scr1_tb_log_cmd.sv>
/// @brief      Lab 3 (variant 5): NON-SYNTHESIZABLE pipeline monitor.
///             Detects the "xor" instruction in the SCR1 pipeline and prints
///             debug information: the state registers of the core.
///             Simulation only (uses $display and hierarchical references).
///

`include "scr1_arch_description.svh"
`include "scr1_arch_types.svh"
`include "scr1_riscv_isa_decoding.svh"

`define LOG_PIPE scr1_top_tb_ahb.i_top.i_core_top.i_pipe_top
`define LOG_EXU  scr1_top_tb_ahb.i_top.i_core_top.i_pipe_top.i_pipe_exu
`define LOG_CSR  scr1_top_tb_ahb.i_top.i_core_top.i_pipe_top.i_pipe_csr

module scr1_tb_log_cmd (
    input logic clk
);

int unsigned           cycle = 0;
logic [`SCR1_XLEN-1:0] mepc_full;
logic [`SCR1_XLEN-1:0] mtvec_full;

// CSR MEPC is stored without the always-zero low bits (1 bit with RVC, 2 without)
assign mepc_full  = `SCR1_XLEN'(`LOG_CSR.csr_mepc_ff) << (`SCR1_XLEN - $bits(`LOG_CSR.csr_mepc_ff));
// CSR MTVEC = {base[31:6], 5'b0, mode}
assign mtvec_full = {`LOG_CSR.csr_mtvec_base, 5'b00000, `LOG_CSR.csr_mtvec_mode};

// Sampling on the falling edge: all signals of the cycle are already stable
// (sampling on the rising edge races with the registers updated by that edge)
always @(negedge clk) begin
    cycle <= cycle + 1;

    // `exu_queue` is the command that the EXU executes in this cycle (the
    // register after the IDU, or a plain copy of the IDU output if the core is
    // configured without the EXU stage). The instruction retires without an
    // exception in this cycle and it is the register-register ALU command XOR:
    // op1 = rs1, op2 = rs2, rd = op1 ^ op2.
    if (`LOG_PIPE.instret_nexc
        & (`LOG_EXU.exu_queue.ialu_op  == SCR1_IALU_OP_REG_REG)
        & (`LOG_EXU.exu_queue.ialu_cmd == SCR1_IALU_CMD_XOR)) begin

        $display("[cycle %0d] Detect XOR command: pc=0x%08h rvc=%b  x%0d = x%0d ^ x%0d  (0x%08h ^ 0x%08h = 0x%08h)",
            cycle,
            `LOG_PIPE.curr_pc,
            `LOG_EXU.exu_queue.instr_rvc,
            `LOG_EXU.exu_queue.rd_addr,
            `LOG_EXU.exu_queue.rs1_addr,
            `LOG_EXU.exu_queue.rs2_addr,
            `LOG_PIPE.mprf2exu_rs1_data,
            `LOG_PIPE.mprf2exu_rs2_data,
            `LOG_PIPE.exu2mprf_rd_data);

        // self-check of the monitor: the value written back must be rs1 ^ rs2
        if (`LOG_PIPE.exu2mprf_rd_data !== (`LOG_PIPE.mprf2exu_rs1_data ^ `LOG_PIPE.mprf2exu_rs2_data))
            $error("scr1_tb_log_cmd: xor result does not match rs1 ^ rs2");

        $display("    state regs: mstatus{mie=%b mpie=%b} mtvec=0x%08h mie{meie=%b mtie=%b msie=%b} mip{meip=%b mtip=%b msip=%b} mepc=0x%08h mcause{irq=%b code=%0d} mtval=0x%08h",
            `LOG_CSR.csr_mstatus_mie_ff,
            `LOG_CSR.csr_mstatus_mpie_ff,
            mtvec_full,
            `LOG_CSR.csr_mie_meie_ff,
            `LOG_CSR.csr_mie_mtie_ff,
            `LOG_CSR.csr_mie_msie_ff,
            `LOG_CSR.csr_mip_meip,
            `LOG_CSR.csr_mip_mtip,
            `LOG_CSR.csr_mip_msip,
            mepc_full,
            `LOG_CSR.csr_mcause_i_ff,
            `LOG_CSR.csr_mcause_ec_ff,
            `LOG_CSR.csr_mtval_ff);
    end
end

endmodule : scr1_tb_log_cmd
