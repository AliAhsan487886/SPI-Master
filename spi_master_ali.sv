// Combined SPI Master (Mode 0, 8-bit) and 7-segment display driver
// Target: ADXL362 slave, Nexys A7-100T FPGA
// This file contains the SPI Master module, 7-seg driver, and top-level integration
// Each line is commented to explain its function
// Combined SPI Master (Mode 0, 8-bit) and 8 seven-segment displays
// Target: ADXL362 slave, Nexys A7-100T FPGA
// Shows each bit of the 8-bit data on a separate 7-segment display
// Simple SPI Master with Binary Display
// Target: Nexys A7-100T FPGA, ADXL362 Slave
// Features:
// - 8-bit data transmission (MSB first)
// - Mode 0 (CPOL=0, CPHA=0)
// - Binary display on 8 seven-segment displays
// - Status LEDs for operation monitoring

module spi_master_with_7seg (
    input  logic       clk,        // System clock input
    input  logic       rst_n,      // Active low reset input
    input  logic       start,      // Start SPI transaction signal
    input  logic [7:0] data_in,    // 8-bit data to transmit via SPI
    output logic       busy,       // SPI busy flag output
    output logic       done,       // SPI transaction done flag output
    output logic       sclk,       // SPI clock output (to slave)
    output logic       mosi,       // Master Out Slave In data line
    output logic       cs_n,       // Chip Select (active low)
    output logic [6:0] seg         // 7-segment display segments output (a-g)
);

    // SPI clock divider parameter to set SPI clock frequency
    parameter integer CLK_DIV = 4;

    // State encoding for SPI state machine
    typedef enum logic [1:0] {
        IDLE = 2'b00,       // Idle state, waiting for start
        TRANSFER = 2'b01,   // Data transfer in progress
        DONE = 2'b10        // Transfer done state
    } state_t;

    state_t state, next_state;      // Current and next state variables for FSM

    logic [7:0] shift_reg;          // Shift register holding data to send
    logic [2:0] bit_cnt;            // Bit counter (0 to 7) for 8 bits
    logic [1:0] clk_div_cnt;        // Clock divider counter for SPI clock generation
    logic sclk_int;                 // Internal SPI clock signal before output

    // Clock divider for multiplexing 7-seg display (approx 1 kHz)
    logic [16:0] mux_clk_cnt;       // Clock counter for multiplexing
    logic mux_sel;                  // Multiplexer select signal (0=lower nibble, 1=upper nibble)

    // SPI clock generation: divide system clock by CLK_DIV*2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 0;      // Reset clock divider counter
            sclk_int <= 0;         // Reset internal SPI clock to 0
        end else if (state == TRANSFER) begin
            if (clk_div_cnt == CLK_DIV - 1) begin
                clk_div_cnt <= 0;  // Reset divider counter
                sclk_int <= ~sclk_int;  // Toggle SPI clock signal
            end else begin
                clk_div_cnt <= clk_div_cnt + 1;  // Increment divider counter
            end
        end else begin
            clk_div_cnt <= 0;      // Reset divider counter when not transferring
            sclk_int <= 0;         // SPI clock low in idle/done states (CPOL=0)
        end
    end

    // Assign SPI clock output (CPOL=0, so sclk follows sclk_int)
    assign sclk = sclk_int;

    // State machine sequential logic: update current state on clock edge
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;         // Reset state to IDLE
        end else begin
            state <= next_state;   // Update state to next_state
        end
    end

    // State machine combinational logic: determine next state
    always_comb begin
        next_state = state;        // Default to current state
        case (state)
            IDLE: begin
                if (start) next_state = TRANSFER;  // Start transfer on start signal
            end
            TRANSFER: begin
                if (bit_cnt == 3'd7 && sclk_int == 1'b1) begin
                    // After last bit sent on rising edge of sclk, go to DONE
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;   // Return to IDLE after done
            end
            default: next_state = IDLE;  // Default fallback to IDLE
        endcase
    end

    // Data transmission and control signals logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'b0;     // Clear shift register on reset
            bit_cnt <= 3'b0;       // Reset bit counter
            mosi <= 1'b0;          // Clear MOSI line
            cs_n <= 1'b1;          // Deactivate chip select (active low)
            busy <= 1'b0;          // Clear busy flag
            done <= 1'b0;          // Clear done flag
        end else begin
            case (state)
                IDLE: begin
                    cs_n <= 1'b1;    // Deactivate chip select
                    busy <= 1'b0;    // Not busy
                    done <= 1'b0;    // Clear done flag
                    bit_cnt <= 3'b0; // Reset bit counter
                end
                TRANSFER: begin
                    cs_n <= 1'b0;    // Activate chip select (active low)
                    busy <= 1'b1;    // Set busy flag
                    done <= 1'b0;    // Clear done flag

                    // On falling edge of sclk_int, shift out data bit
                    if (clk_div_cnt == 0 && sclk_int == 1'b0) begin
                        mosi <= shift_reg[7];          // Output MSB first on MOSI
                        shift_reg <= {shift_reg[6:0], 1'b0};  // Shift left by 1 bit
                        if (bit_cnt < 3'd7) begin
                            bit_cnt <= bit_cnt + 1;   // Increment bit counter
                        end
                    end
                end
                DONE: begin
                    cs_n <= 1'b1;    // Deactivate chip select
                    busy <= 1'b0;    // Clear busy flag
                    done <= 1'b1;    // Set done flag to indicate transaction complete
                end
                default: begin
                    cs_n <= 1'b1;    // Default deactivate chip select
                    busy <= 1'b0;    // Default clear busy
                    done <= 1'b0;    // Default clear done
                end
            endcase
        end
    end

    // Load data into shift register at start of transfer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'b0;     // Clear shift register on reset
        end else if (state == IDLE && start) begin
            shift_reg <= data_in;  // Load input data into shift register
        end
    end

    // Multiplexing clock for 7-seg display (approx 1 kHz)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_clk_cnt <= 0;      // Reset mux clock counter
            mux_sel <= 0;          // Start with lower nibble
        end else begin
            if (mux_clk_cnt == 49999) begin  // Assuming 100 MHz clk, toggle every 0.5 ms
                mux_clk_cnt <= 0;
                mux_sel <= ~mux_sel;          // Toggle mux select to switch nibble
            end else begin
                mux_clk_cnt <= mux_clk_cnt + 1;
            end
        end
    end

    // Select nibble to display based on mux_sel
    logic [3:0] nibble_to_display;
    always_comb begin
        if (mux_sel == 0)
            nibble_to_display = data_in[3:0];  // Lower nibble
        else
            nibble_to_display = data_in[7:4];  // Upper nibble
    end

    // 7-segment display driver logic for selected nibble
    always_comb begin
        case (nibble_to_display)          // Decode 4-bit hex digit to 7-seg segments
            4'h0: seg = 7'b1111110; // Display 0
            4'h1: seg = 7'b0110000; // Display 1
            4'h2: seg = 7'b1101101; // Display 2
            4'h3: seg = 7'b1111001; // Display 3
            4'h4: seg = 7'b0110011; // Display 4
            4'h5: seg = 7'b1011011; // Display 5
            4'h6: seg = 7'b1011111; // Display 6
            4'h7: seg = 7'b1110000; // Display 7
            4'h8: seg = 7'b1111111; // Display 8
            4'h9: seg = 7'b1111011; // Display 9
            4'hA: seg = 7'b1110111; // Display A
            4'hB: seg = 7'b0011111; // Display b
            4'hC: seg = 7'b1001110; // Display C
            4'hD: seg = 7'b0111101; // Display d
            4'hE: seg = 7'b1001111; // Display E
            4'hF: seg = 7'b1000111; // Display F
            default: seg = 7'b0000000; // Blank display for invalid input
        endcase
    end

endmodule
