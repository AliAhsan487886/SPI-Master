
// Testbench for spi_master_with_7seg module
// Simulates SPI Master transaction and 7-seg display output
// Testbench for spi_master_final module
// Simulates SPI Master transmission and 7-seg display output

module spi_master_ali_tb;

    logic clk;
    logic rst_n;
    logic start;
    logic [7:0] data_in;
    logic busy;
    logic done;
    logic sclk;
    logic mosi;
    logic cs_n;
    logic [6:0] seg [7:0];
    logic [7:0] led_data;

    // Instantiate the DUT (Device Under Test)
    spi_master_ali dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .seg(seg),
        .led_data(led_data)
    );

    // Clock generation: 100 MHz clock (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        data_in = 8'h00;

        // Release reset after some time
        #100;
        rst_n = 1;

        // Wait for a few clock cycles
        #50;

        // Start SPI transaction with data 0xA5
        data_in = 8'hA5;
        start = 1;
        #10;
        start = 0;

        // Wait for transaction to complete
        wait(done == 1);

        // Wait some time and start another transaction with data 0x3C
        #100;
        data_in = 8'h3C;
        start = 1;
        #10;
        start = 0;

        // Wait for transaction to complete
        wait(done == 1);

        // Finish simulation
        #100;
        $stop;
    end

endmodule
