module top(
    input  logic        clk, reset_L,
    input  logic        valid_in, dma_ready,
    output logic        valid_out,
    input  logic [31:0] data_in, 
    output logic [31:0] data_out
);

    logic [8:0][8:0][8:0] input_vector; // Could just load the solver register
    logic [8:0][8:0][3:0] output_vector;
   
    logic [3:0] curr_row_INPUT, curr_col_INPUT, curr_row_OUTPUT, curr_col_OUTPUT;
    logic       addr_en_INPUT, addr_en_OUTPUT, puzzle_go, puzzle_done; 

    solver #(9, 3) SOLVER(
        .initial_vals(input_vector),
        .start(puzzle_go),
        .clock(clk),
        .reset_L,
        //.fail(),
        //.final_vals(),
        .human_readable_vals(output_vector),
        .done(puzzle_done)
    );

    generate
        genvar i, j;
        for(i = 0; i < 9; i++) begin
            for(j = 0; j < 9; j++) begin
                logic [8:0] data_in_decoded;
                bcd_decoder INPUT_DECODER(data_in[3:0], data_in_decoded);
                register #(9) input_vector_buffer(
                    .clk, .reset_L,
                    .D(data_in_decoded),
                    .Q(input_vector[i][j]),
                    .en(
                        (curr_row_INPUT == i) & // Row 
                        (curr_col_INPUT == j) & // Col
                        (valid_in)
                    )
                );
            end
        end
    endgenerate

    transferInputFSM INPUT_FSM(
        .clk, .rst_L(reset_L),
        .valid(valid_in),
        .addr_en(addr_en_INPUT),
        .done(puzzle_go)
    );

    transferOutputFSM OUTPUT_FSM(
        .clk, .rst_L(reset_L),
        .valid(valid_out),
        .addr_en(addr_en_OUTPUT),
        .row(curr_row_OUTPUT),
        .col(curr_col_OUTPUT),
        .done(puzzle_done && dma_ready),       // Given by hardware
        .valid_in
    );

    counter #(4) CURR_ROW_INPUT(
        .clk, .rst_L(reset_L),
        .count(curr_row_INPUT),
        .en(addr_en_INPUT && curr_col_INPUT == 4'd8),
        .clear(curr_row_INPUT == 4'd8 && curr_col_INPUT == 4'd8)
    );

    counter #(4) CURR_COL_INPUT(
        .clk, .rst_L(reset_L),
        .clear(curr_col_INPUT == 4'd8),
        .en(addr_en_INPUT),
        .count(curr_col_INPUT)
    );

    counter #(4) CURR_ROW_OUTPUT(
        .clk, .rst_L(reset_L),
        .count(curr_row_OUTPUT),
        .en(addr_en_OUTPUT && curr_col_OUTPUT == 4'd8),
        .clear(curr_row_OUTPUT == 4'd8 && curr_col_OUTPUT == 4'd8)
    );

    counter #(4) CURR_COL_OUTPUT(
        .clk, .rst_L(reset_L),
        .clear(curr_col_OUTPUT == 4'd8),
        .count(curr_col_OUTPUT),
        .en(addr_en_OUTPUT)
    );

    assign data_out = {28'd0, output_vector[curr_row_OUTPUT][curr_col_OUTPUT]};

endmodule: top

module transferInputFSM(
    input  logic clk, rst_L,
    input  logic valid,
    output logic addr_en, done
);

    enum logic [1:0] {Wait, Go, Done} cs, ns;

    always_comb begin
        case(cs)
            Wait: ns = (valid) ? Go : Wait;
            Go:   ns = (~valid) ? Done : Go;
            Done: ns = Wait;
        endcase
    end

    always_comb begin
        addr_en = 0;
        done = 0;
        case(cs)
            Wait: addr_en = (valid);
            Go:   addr_en = (valid);
            Done: done = 1;
        endcase
    end

    always_ff @(posedge clk, negedge rst_L)
        cs <= (~rst_L) ? Wait : ns;

endmodule: transferInputFSM

module transferOutputFSM(
    input  logic clk, rst_L,
    output logic valid,
    output logic addr_en, 
    input  logic done, valid_in,
    input  logic [3:0] row, col
);

    enum logic [1:0] {Wait, Go, Done} cs, ns;

    always_comb begin
        case(cs)
            Wait: ns = (done) ? Go : Wait;
            Go:   ns = (row == 4'd8 && col == 4'd8) ? Done : Go;
            Done: ns = (valid_in) ? Wait : Done;
        endcase
    end

    always_comb begin
        addr_en = 0;
        valid = 0;
        case(cs)
            Wait: begin
                addr_en = (done);
                valid = (done);
            end
            Go: begin
                addr_en = 1;
                valid = 1;
            end
            Done: begin
                valid = 0;
            end
        endcase
    end

    always_ff @(posedge clk, negedge rst_L)
        cs <= (~rst_L) ? Wait : ns;

endmodule: transferOutputFSM


module solver #(parameter WIDTH = 9, N = 3) (
    input logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] initial_vals,
    input logic start, clock, reset_L,
    //output logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_vals,
    output logic [WIDTH-1:0][WIDTH-1:0][3:0] human_readable_vals,
    output logic done
    );

    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options, new_options;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_rows, final_cols, final_sectors, final_vals;
    logic [WIDTH-1:0][WIDTH-1:0] row_vals, col_vals, sector_vals, overall_fail, overall_done;
    logic fail;

    assign fail = |overall_fail;
    assign done = &overall_done || fail;
    
    generate
        genvar row, col;
        for(row = 0; row < WIDTH; row++) begin: row_square
            for(col = 0; col < WIDTH; col++) begin: col_square
                bcd_encoder bcde(final_vals[row][col], human_readable_vals[row][col]);
                square #(WIDTH, N) s(
                       .row(row_vals[row]), 
                       .col(col_vals[col]), 
                       .sector(sector_vals[(row/N)*N + (col/N)]),
                       .det_val(new_options[row][col]),
                       .initial_val(initial_vals[row][col]), .clock, .reset_L,
                       .load_initial(start), 
                       .options_out(options[row][col]),
                       .final_val(final_vals[row][col]), 
                       .fail(overall_fail[row][col]),
                       .done(overall_done[row][col])
                );
            end
        end

        for(row = 0; row < WIDTH; row++) begin: row_final

            logic [WIDTH-1:0] i;
            always_comb begin
                row_vals[row] = 0;
                col_vals[row] = 0;
                sector_vals[row] = 0;
                for (i = 0; i < WIDTH; i++) begin
                    row_vals[row] = row_vals[row] | final_rows[row][i];
                    col_vals[row] = col_vals[row] | final_cols[row][i];
                    sector_vals[row] = sector_vals[row] | final_sectors[row][i];
                end
            end

            for(col = 0; col < WIDTH; col++) begin: col_final
                assign final_rows[row][col] = final_vals[row][col];
                assign final_cols[col][row] = final_vals[row][col];
                assign final_sectors[(row/N)*N + (col/N)][(row%N)*N + (col %N)] = final_vals[row][col];
            end
        end

    endgenerate

    options_gen #(WIDTH, N) o(options, new_options);

endmodule: solver


module options_gen #(parameter WIDTH = 9, N = 3) (
    //     row          col         bit
    input logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options,
    output logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] new_options);

    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_row_t, new_options_row_t;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_col_t, new_options_col_t;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_sector_t, new_options_sector_t;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] new_options_row, new_options_col, new_options_sector;

    assign new_options = new_options_row | new_options_col | new_options_sector;
    generate
        genvar row, col, sector, bits, bit_index;
        for(row = 0; row < WIDTH; row++) begin: row_calc
            for(col = 0; col < WIDTH; col++) begin: col_calc
                for(bits = 0; bits < WIDTH; bits++) begin: bits_calc
                    assign options_row_t[row][bits][col] = options[row][col][bits];
                    assign new_options_row[row][col][bits] = new_options_row_t[row][bits][col];
                end
            end
            for(bit_index = 0; bit_index < WIDTH; bit_index++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) ohd(~options_row_t[row][bit_index], is_hot);
                assign new_options_row_t[row][bit_index] = is_hot ? ~options_row_t[row][bit_index] : 0;
            end
        end
        for(col = 0; col < WIDTH; col++) begin: col_calc
            for(row = 0; row < WIDTH; row++) begin: row_calc
                for(bits = 0; bits < WIDTH; bits++) begin: bits_calc
                    assign options_col_t[col][bits][row] = options[row][col][bits];
                    assign new_options_col[row][col][bits] = new_options_col_t[col][bits][row];
                end
            end
            for(bit_index = 0; bit_index < WIDTH; bit_index++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) ohd(~options_col_t[col][bit_index], is_hot);
               assign new_options_col_t[col][bit_index] = is_hot ? ~options_col_t[col][bit_index] : 0;
            end
        end
        for(sector = 0; sector < WIDTH; sector++) begin: sector_calc
            for(row = 0; row < N; row++) begin: row_calc
                for(col = 0; col < N; col++) begin: col_calc
                    for(bits = 0; bits < WIDTH; bits++) begin: bits_calc
                        assign options_sector_t[sector][bits][row*N+col] = options[(sector/N)*N+row][(sector%N)*N + col][bits];
                        assign new_options_sector[(sector/N)*N+row][(sector%N)*N + col][bits] = new_options_sector_t[sector][bits][row*N+col];
                    end
                end
            end
            for(bit_index = 0; bit_index < WIDTH; bit_index++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) ohd(~options_sector_t[sector][bit_index], is_hot);
                assign new_options_sector_t[sector][bit_index] = is_hot ? ~options_sector_t[sector][bit_index] : 0;
            end
        end
    endgenerate

endmodule: options_gen


module square #(parameter WIDTH = 9, N = 3) (
    input logic [WIDTH-1:0] row, col, sector, det_val, initial_val,
    input logic clock, reset_L, load_initial,
    output [WIDTH-1:0] options_out, final_val,
    output logic fail, done);

    logic [WIDTH-1:0] internal_det_val, load_val, options;//, options_before_latch;
    logic valid, load;

    assign internal_det_val = (det_val == 0) ? det_val : ~det_val;
    assign options = row | col | sector | internal_det_val;
    one_hot_detector #(WIDTH) ohd(~options, valid);
    assign load_val = load_initial ? initial_val : ~options;
    assign load = (valid || load_initial) && !(final_val);

    register #(WIDTH) r1(final_val, load_val, load, clock, reset_L);
    //register #(WIDTH) r2(options_out, options_before_latch, ~(valid || load_initial), clock, reset_L);

    assign all_ones = &options;
    assign fail = all_ones && (final_val == 0);
    assign done = (final_val != 0);
    assign options_out = (final_val == 0) ? (row | col | sector) : {WIDTH{1'b1}};

endmodule: square


module one_hot_detector #(parameter WIDTH = 9) (
    input logic [WIDTH-1:0] in,
    output logic is_one_hot);

    assign is_one_hot = (in && !(in & (in-1)));

endmodule: one_hot_detector

module register #(parameter WIDTH = 8) (
   output logic [WIDTH-1:0] Q,
   input  logic [WIDTH-1:0] D,
   input  logic             en,
   input  logic             clk,
   input  logic             reset_L);

   always_ff @ (posedge clk, negedge reset_L) begin
      if(~reset_L)
         Q <= 'h0000;
      else if (en)
         Q <= D;
   end

endmodule: register

module counter #(parameter WIDTH = 8) (
    output logic [WIDTH-1:0] count,
    input  logic             clk, rst_L, clear, en
);

    always_ff @(posedge clk, negedge rst_L) begin
        if (~rst_L)     count <= 0;
        else if (clear) count <= 0;
        else if (en)    count <= count + 1;
    end
 
endmodule: counter

module bcd_encoder(
    input logic [8:0] in,
    output logic [3:0] out);

    always_comb begin
        case(in)
            9'b000000000: out = 0;
            9'b000000001: out = 1;
            9'b000000010: out = 2;
            9'b000000100: out = 3;
            9'b000001000: out = 4;
            9'b000010000: out = 5;
            9'b000100000: out = 6;
            9'b001000000: out = 7;
            9'b010000000: out = 8;
            9'b100000000: out = 9;
            default: out = 0;
        endcase
    end

endmodule: bcd_encoder

module bcd_decoder(
    input  logic [3:0] in,
    output logic [8:0] out
);

    always_comb begin
        case(in)
            4'd0: out = 9'b0_0000_0000;
            4'd1: out = 9'b0_0000_0001;
            4'd2: out = 9'b0_0000_0010;
            4'd3: out = 9'b0_0000_0100;
            4'd4: out = 9'b0_0000_1000;
            4'd5: out = 9'b0_0001_0000;
            4'd6: out = 9'b0_0010_0000;
            4'd7: out = 9'b0_0100_0000;
            4'd8: out = 9'b0_1000_0000;
            4'd9: out = 9'b1_0000_0000;
            default: out = 9'd0;
        endcase
    end

endmodule: bcd_decoder

module solver_TB;

    logic        clk, reset_L, valid_in, valid_out, dma_ready;
    logic [31:0] data_in, data_out;

    logic [80:0][31:0] data_stream_in, data_stream_out;
    
    top DUT(.*);

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    logic [6:0] i;

    assign data_in = data_stream_in[i];
    
    initial begin

        data_stream_in = {32'd0, 32'd2, 32'd7, 32'd0, 32'd4, 32'd0, 32'd8, 32'd0, 32'd0,
                          32'd0, 32'd1, 32'd0, 32'd7, 32'd0, 32'd0, 32'd9, 32'd4, 32'd0,
                          32'd4, 32'd0, 32'd8, 32'd2, 32'd0, 32'd0, 32'd3, 32'd5, 32'd0,
                          32'd0, 32'd0, 32'd9, 32'd0, 32'd5, 32'd0, 32'd0, 32'd0, 32'd0,
                          32'd5, 32'd0, 32'd0, 32'd8, 32'd7, 32'd4, 32'd0, 32'd0, 32'd6,
                          32'd0, 32'd0, 32'd0, 32'd0, 32'd1, 32'd0, 32'd4, 32'd0, 32'd0,
                          32'd0, 32'd7, 32'd4, 32'd0, 32'd0, 32'd9, 32'd6, 32'd0, 32'd8,
                          32'd0, 32'd9, 32'd6, 32'd0, 32'd0, 32'd7, 32'd0, 32'd3, 32'd0,
                          32'd0, 32'd0, 32'd3, 32'd0, 32'd2, 32'd0, 32'd7, 32'd1, 32'd0};

        dma_ready = 0;
        valid_in = 0;
        i = 0;
        
        reset_L = 1;
        @(posedge clk);
        reset_L <= 0;
        @(posedge clk);
        reset_L <= 1;
        @(posedge clk);
        @(posedge clk);
        valid_in <= 1;
        
        for (; i < 81; i++) begin
            @(posedge clk);
        end

        i <= 0;
        valid_in <= 0;
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        dma_ready <= 1;
        
        for (i = 0; i < 81; i++) begin
            @(posedge clk);
        end

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        $finish;
    end
    
endmodule: solver_TB
