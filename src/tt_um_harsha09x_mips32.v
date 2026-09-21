`default_nettype none

module tt_um_harsha09x_mips32 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // Bidirectional path: Input mode
    output wire [7:0] uio_out,  // Bidirectional path: Output mode
    output wire [7:0] uio_oe,   // Bidirectional path: Output Enable (1=out, 0=in)
    input  wire       ena,      // will be driven high when the design is selected
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // 1. Configure all bidirectional pins strictly as OUTPUTS
    assign uio_oe = 8'b11111111;

    // 2. Extract specific control lines from input pins
    wire [1:0] bus_sel = ui_in[7:6]; // Controls what data we load or read
    wire [5:0] data_in = ui_in[5:0]; // 6-bit chunk of data arriving from outside

    // 3. Internal registers to reconstruct the 32-bit instruction stream
    reg [31:0] internal_instruction;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            internal_instruction <= 32'b0;
        end else begin
            // Load 6-bit slices of the 32-bit instruction based on selection state
            case (bus_sel)
                2'b00: internal_instruction[5:0]   <= data_in;
                2'b01: internal_instruction[11:6]  <= data_in;
                2'b10: internal_instruction[17:12] <= data_in;
                2'b11: internal_instruction[23:18] <= data_in; // Last bits filled with 0s automatically
            endcase
        end
    end

    // 4. Connect to internal wire hooks for MIPS CPU Outputs
    wire [31:0] mips_alu_out;

    // 5. Instantiate your repository's MIPS processor core core
    // NOTE: Match these port names exactly with the module ports inside your 'mips32.v'
    mips32 processor_core (
        .clk(clk),
        .sys_rst(!rst_n), // Invert active-low reset if your MIPS uses active-high
        
        // Pass the re-assembled 32-bit wide instruction into the CPU core
        .instruction(internal_instruction), 
        
        // Output from the CPU
        .alu_result(mips_alu_out)
    );

    // 6. Multiplex the broad 32-bit output back down to the 16 available output pins
    // Combine uo_out (8 bits) and uio_out (8 bits) to form a unified 16-bit monitoring bus
    assign {uio_out, uo_out} = (bus_sel[0] == 1'b0) ? mips_alu_out[15:0] : mips_alu_out[31:16];

endmodule
