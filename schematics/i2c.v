`timescale 1ns/1ns
module i2c (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] addr,
    input wire [7:0] data,
    output reg busy,
    output reg scl,
    inout wire sda
);

    // State Encoding
    parameter IDLE = 3'd0;
    parameter START = 3'd1;
    parameter ADDR = 3'd2;
    parameter ACK_ADDR = 3'd3;  // NEW: ACK after Address
    parameter DATA = 3'd4;
    parameter ACK_DATA = 3'd5;  // NEW: ACK after Data
    parameter STOP = 3'd6;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg sda_out;
    reg sda_en;
    reg ack_error;  // NEW: ACK error flag

    // SDA Tri-state Buffer
    assign sda = sda_en ? sda_out : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scl <= 1'b1;
            sda_en <= 1'b0;
            sda_out <= 1'b1;
            busy <= 1'b0;
            bit_cnt <= 4'd0;
            shift_reg <= 8'd0;
            ack_error <= 1'b0;  // NEW
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    scl <= 1'b1;
                    sda_en <= 1'b0;
                    ack_error <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        shift_reg <= {addr, 1'b0};  // Address + Write bit
                        state <= START;
                    end
                end

                START: begin
                    sda_en <= 1'b1;
                    sda_out <= 1'b0;  // Pull SDA low while SCL high
                    scl <= 1'b0;      // Pull SCL low to begin
                    state <= ADDR;
                    bit_cnt <= 4'd7;
                end

                ADDR: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_en <= 1'b1;
                        sda_out <= shift_reg[bit_cnt];
                    end else begin
                        if (bit_cnt == 0) begin
                            state <= ACK_ADDR;  // Go to ACK state
                            scl <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // NEW: ACK After Address
                ACK_ADDR: begin
                    scl <= ~scl;
                    sda_en <= 1'b0;  // Release SDA — Slave will drive it
                    if (scl) begin   // Sample on rising edge
                        if (sda !== 1'b0) begin
                            ack_error <= 1'b1;  // NACK received
                            state <= STOP;
                        end else begin
                            // ACK received — proceed to DATA
                            shift_reg <= data;
                            bit_cnt <= 4'd7;
                            state <= DATA;
                        end
                    end
                end

                DATA: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_en <= 1'b1;
                        sda_out <= shift_reg[bit_cnt];
                    end else begin
                        if (bit_cnt == 0) begin
                            state <= ACK_DATA;  // Go to ACK state
                            scl <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // NEW: ACK After Data
                ACK_DATA: begin
                    scl <= ~scl;
                    sda_en <= 1'b0;  // Release SDA — Slave will drive it
                    if (scl) begin   // Sample on rising edge
                        if (sda !== 1'b0) begin
                            ack_error <= 1'b1;  // NACK received
                        end
                        state <= STOP;  // Proceed to STOP either way
                    end
                end

                STOP: begin
                    scl <= 1'b1;
                    sda_en <= 1'b1;
                    sda_out <= 1'b0;
                    if (scl) begin
                        sda_out <= 1'b1;  // SDA rises while SCL high = STOP
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule