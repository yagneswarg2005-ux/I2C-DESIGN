`timescale 1ns/1ns
`include "../../schematics/i2c.v"

module i2c_tb;
    // 1. Inputs as reg, Outputs as wire
    reg clk;
    reg rst_n;
    reg start;
    reg [6:0] addr;
    reg [7:0] data;
    wire busy;
    wire scl;
    wire sda;
    reg sda_slave;

    i2c uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .addr(addr),
        .data(data),
        .busy(busy),
        .scl(scl),
        .sda(sda)
    );

    pullup(sda);
    pullup(scl);
    assign sda = sda_slave;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        sda_slave = 1'bz;
        repeat(8) @(posedge scl);
        @(negedge scl);  // 9th SCL falling edge
        sda_slave = 1'b0;  // Pull LOW = ACK
        $display("ACK sent after Address at time %0t", $time);
        @(negedge scl);
        sda_slave = 1'bz;  // Release SDA

        repeat(8) @(posedge scl);
        @(negedge scl);  // 9th SCL falling edge
        sda_slave = 1'b0;  // Pull LOW = ACK
        $display("ACK sent after Data at time %0t", $time);
        @(negedge scl);
        sda_slave = 1'bz;  // Release SDA
    end

    initial begin
        $fsdbDumpvars();

        // Reset
        rst_n = 1'b0;
        start = 1'b0;
        addr = 7'b0;
        data = 8'b0;
        #20 rst_n = 1'b1;

        // Transaction: addr=0x5A, data=0xA5
        #20;
        @(posedge clk);
        addr = 7'h5A;
        data = 8'hA5;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(busy == 1'b0);
        #100;

        if (uut.ack_error)
            $display(" NACK received - Transaction Failed!");
        else
            $display(" ACK received - Transaction Successful!");

        $fsdbDumpflush();
        $display("Simulation Completed Successfully.");
        $finish;
    end

endmodule