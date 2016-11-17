module top #(parameter WIDTH = 9, N = 3) (
    input logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] initial_vals,
    input logic start, clock, reset_L,
    output logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_vals,
    output logic fail);

    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options, new_options;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] final_rows, final_cols, final_sectors;
    logic [WIDTH-1:0][WIDTH-1:0] row_vals, col_vals, sector_vals, overall_fail;

    assign fail = |overall_fail;
    generate
        genvar row, col;
        for(row = 0; row < WIDTH; row++) begin: row_square
            for(col = 0; col < WIDTH; col++) begin: col_square
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

endmodule: top


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

    logic [WIDTH-1:0] internal_det_val, load_val, options, options_before_latch;
    logic valid;

    assign internal_det_val = (det_val == 0) ? det_val : ~det_val;
    assign options = row | col | sector | internal_det_val;
    one_hot_detector #(WIDTH) ohd(~options, valid);
    assign load_val = load_initial ? initial_val : ~options;

    register #(WIDTH) r1(final_val, load_val, (~valid || load_initial), clock, reset_L);
    register #(WIDTH) r2(options_out, options_before_latch, (~valid || load_initial), clock, reset_L);

    assign all_ones = &options;
    assign fail = all_ones && (final_val == 0);
    assign options_before_latch = (final_val == 0) ? options : {WIDTH-1{1'b1}};

endmodule: square


module one_hot_detector #(parameter WIDTH = 9) (
    input logic [WIDTH-1:0] in,
    output logic is_one_hot);

    assign is_one_hot = (in && !(in & (in-1)));

endmodule

module register #(parameter WIDTH = 16) (
   output logic [WIDTH-1:0] out,
   input [WIDTH-1:0]      in,
   input                  load_L,
   input                  clock,
   input                  reset_L);

   always_ff @ (posedge clock, negedge reset_L) begin
      if(~reset_L)
         out <= 'h0000;
      else if (~load_L)
         out <= in;
   end

endmodule

module solver_TB;

  logic [3:0][3:0][3:0] initial_vals, final_vals;
  logic start, clock, reset_L, fail;

  top #(4, 2) DUT(.*);

  initial begin
      clock = 0;
      forever #5 clock = ~clock;
  end

  initial begin
    reset_L = 1;
    initial_vals = 64'h0040_2000_1200_0001;
    #2;
    reset_L <= 0;
    @(posedge clock);
    reset_L <= 1;
    start <= 1;
    @(posedge clock);
    start <= 0;
    @(posedge clock);
    #5000 $finish;
  end

endmodule: solver_TB
