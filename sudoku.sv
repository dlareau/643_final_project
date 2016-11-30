module top(
    input  logic        clk, reset, start,
    input  logic        valid_in,
    output logic        valid_out,
    input  logic [31:0] data_in, 
    output logic [31:0] data_out
);

    logic [8:0][8:0][8:0] input_vector; // Could just load the solver register
    logic [8:0][8:0][3:0] output_vector;
   
    logic reset_L;
    logic [6:0] addr_in_INPUT, addr_out_INPUT, addr_in_OUTPUT, addr_out_OUTPUT;
    logic       addr_en_INPUT, addr_en_OUTPUT, puzzle_go, puzzle_done; 
    
    assign reset_L = ~reset; 

    solver SOLVER(.initial_vals(input_vector),
           .start(/*NEEDS TO BE DELAYED*/),
           .clock(clk),
           .reset_L,
           //.fail(),
           //.final_vals(),
           .human_readable_vals(output_vector)
           );

    generate
        genvar i, j;
        for(i = 0; i < 9; i++) begin
            for(j = 0; j < 9; j++) begin
                register #(9) input_vector_buffer(
                    .clk, .reset_L,
                    .D(data_in[8:0]), //NEEDS DECODING
                    .Q(input_vector[i][j]),
                    .en(/* the ith/jth entry*/)
                );
            end
        end
    endgenerate

    transferInputFSM iFSM(
        .clk, .rst_L(reset_L),
        .valid(valid_in),
        .addr_en(addr_en_INPUT),
        .done(puzzle_go)
    );

    transferOutputFSM oFSM(
        .clk, .rst_L(reset_L),
        .valid(valid_out),
        .addr_en(addr_en_OUTPUT),
        .addr(addr_out_OUTPUT),
        .done(puzzle_done)       // Given by hardware
    );

    register #(7) CURR_REG_INPUT(
        .clk, .reset_L,
        .D(addr_in_INPUT),
        .Q(addr_out_INPUT),
        .en(addr_en_INPUT)
    );

    register #(7) CURR_REG_OUTPUT(
        .clk, .reset_L,
        .D(addr_in_OUTPUT),
        .Q(addr_out_OUTPUT),
        .en(addr_en_OUTPUT)
    );
  
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
            Go:   addr_en = 1;
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
    input  logic done,
    input  logic [6:0] addr
);

    enum logic {Wait, Go} cs, ns;

    always_comb begin
        case(cs)
            Wait: ns = (done) ? Go : Wait;
            Go:   ns = (addr == 7'd81) ? Wait : Go;
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
        endcase
    end

    always_ff @(posedge clk, negedge rst_L)
        cs <= (~rst_L) ? Wait : ns;

endmodule: transferOutputFSM


module solver #(parameter WIDTH = 9, N = 3) (
    input logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] initial_vals,
    input logic start, clock, reset_L,
    //output logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_vals,
    output logic [WIDTH-1:0][WIDTH-1:0][3:0] human_readable_vals
    //output logic fail
    );

    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options, new_options;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_rows, final_cols, final_sectors, final_vals;
    logic [WIDTH-1:0][WIDTH-1:0] row_vals, col_vals, sector_vals, overall_fail;
    logic fail;

    assign fail = |overall_fail;
    generate
        genvar row, col;
        for(row = 0; row < WIDTH; row++) begin: row_square
            for(col = 0; col < WIDTH; col++) begin: col_square
                bcd_encoder bcde(final_vals[row][col], human_readable_vals[row][col]);
                square #(WIDTH, N) s(.row(row_vals[row]), .col(col_vals[col]), .sector(sector_vals[(row/N)*N + (col/N)]),
                       .det_val(new_options[row][col]),
                       .initial_val(initial_vals[row][col]), .clock, .reset_L,
                       .load_initial(start), .options_out(options[row][col]),
                       .final_val(final_vals[row][col]), .fail(overall_fail[row][col]));
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
    output logic fail);

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
    assign options_out = (final_val == 0) ? (row | col | sector) : {WIDTH{1'b1}};

endmodule: square


module one_hot_detector #(parameter WIDTH = 9) (
    input logic [WIDTH-1:0] in,
    output logic is_one_hot);

    assign is_one_hot = (in && !(in & (in-1)));

endmodule

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

endmodule

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


/*
module solver_TB;

    logic [8:0][8:0][8:0] initial_vals, final_vals;
    logic [8:0][8:0][3:0] human_readable_vals;
    logic start, clock, reset_L, fail;
  
    //top #(9, 3) DUT(.*);
    input_puzzle INPUT(
        .clka(),
        .wea(1'b0),
        .addra(),
        .dina(), 
        .douta(), 
        .clkb(),
        .web(1'b0),
        .addrb(),
        .dinb(),
        .doutb()
    );

  initial begin
    initial_vals[0] = 81'b000000000_000000010_001000000_000000000_000001000_000000000_010000000_000000000_000000000;
    initial_vals[1] = 81'b000000000_000000001_000000000_001000000_000000000_000000000_100000000_000001000_000000000;
    initial_vals[2] = 81'b000001000_000000000_010000000_000000010_000000000_000000000_000000100_000010000_000000000;
    initial_vals[3] = 81'b000000000_000000000_100000000_000000000_000010000_000000000_000000000_000000000_000000000;
    initial_vals[4] = 81'b000010000_000000000_000000000_010000000_001000000_000001000_000000000_000000000_000100000;
    initial_vals[5] = 81'b000000000_000000000_000000000_000000000_000000001_000000000_000001000_000000000_000000000;
    initial_vals[6] = 81'b000000000_001000000_000001000_000000000_000000000_100000000_000100000_000000000_010000000;
    initial_vals[7] = 81'b000000000_100000000_000100000_000000000_000000000_001000000_000000000_000000100_000000000;
    initial_vals[8] = 81'b000000000_000000000_000000100_000000000_000000010_000000000_001000000_000000001_000000000;
  end

endmodule: solver_TB
*/
