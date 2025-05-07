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

module spi_master_ali (
    input  logic       clk,        // 100MHz system clock
    input  logic       rst_n,      // Active low reset (CPU_RESETN button)
    input  logic       start,      // Start transmission (BTNU button)
    input  logic [7:0] data_in,    // 8-bit data from switches SW[7:0]
    
    // SPI outputs
    output logic       sclk,       // Serial clock to slave
    output logic       mosi,       // Master Out Slave In
    output logic       cs_n,       // Chip select (active low)
    
    // Status outputs
    output logic       busy,       // Transaction in progress (LED0)
    output logic       done,       // Transaction complete (LED1)
    output logic [7:0] led_data,   // Data being sent (LED15-LED8)
    
    // Binary display outputs (7-segment)
    output logic [6:0] seg [7:0]   // Array of 8 displays [MSB to LSB]
);

    // Parameters
    parameter int CLK_FREQ = 100_000_000;  // 100 MHz system clock
    parameter int SPI_FREQ = 1_000_000;    // 1 MHz SPI clock
    parameter int CLK_DIV = CLK_FREQ/(2*SPI_FREQ) - 1;  // Clock divider value

    // State definitions
    typedef enum logic [1:0] {
        IDLE,       // Waiting for start
        TRANSFER,   // Sending data
        DONE        // Transfer complete
    } state_t;

    // Internal signals
    state_t state;
    logic [7:0] shift_reg;    // Shift register for transmission
    logic [2:0] bit_count;    // Counts bits sent (0-7)
    logic [7:0] clk_count;    // Counter for SPI clock division

    // Connect data to status LEDs
    assign led_data = data_in;

    // Main state machine and data transmission
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all signals
            state <= IDLE;
            shift_reg <= '0;
            bit_count <= '0;
            clk_count <= '0;
            sclk <= '0;
            mosi <= '0;
            cs_n <= '1;
            busy <= '0;
            done <= '0;
        end
        else begin
            case (state)
                IDLE: begin
                    // Wait for start signal
                    if (start) begin
                        state <= TRANSFER;
                        shift_reg <= data_in;  // Load data
                        cs_n <= '0;            // Assert chip select
                        busy <= '1;
                        done <= '0;
                    end
                end

                TRANSFER: begin
                    // Generate SPI clock and send data
                    if (clk_count == CLK_DIV) begin
                        clk_count <= '0;
                        sclk <= ~sclk;
                        
                        // Send bit on falling edge
                        if (sclk) begin
                            if (bit_count == 7) begin
                                state <= DONE;
                            end
                            else begin
                                bit_count <= bit_count + 1;
                            end
                            mosi <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end
                    end
                    else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DONE: begin
                    // Complete transaction
                    cs_n <= '1;
                    busy <= '0;
                    done <= '1;
                    sclk <= '0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Binary display logic - shows 1 or 0 on each display
    // '0' pattern: 1111110 (0x7E)
    // '1' pattern: 0110000 (0x30)
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            seg[i] = data_in[7-i] ? 7'b0110000 : 7'b1111110;
        end
    end

endmodule
