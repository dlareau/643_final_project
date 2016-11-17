module solver #(parameter WIDTH = 9, N = 3) (
    //     row          col         bit
    input logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options,
    output logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] new_options_row, new_options_col, new_options_sector, options_col_t);

    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_row_t, new_options_row_t;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_col_t, new_options_col_t;
    logic [WIDTH-1:0][WIDTH-1:0][WIDTH-1:0] options_sector_t, new_options_sector_t;

    generate
        genvar row, col, sector, sub_row, sub_col, num_bits;
        for(row = 0; row < WIDTH; row++) begin: row_calc
            for(sub_row = 0; sub_row < WIDTH; sub_row++) begin: sub_row_calc
                for(sub_col = 0; sub_col < WIDTH; sub_col++) begin: sub_col_calc
                    assign options_row_t[row][sub_row][sub_col] = options[row][sub_col][sub_row];
                    assign new_options_row[row][sub_col][sub_row] = new_options_row_t[row][sub_row][sub_col];
                end 
            end
            for(num_bits = 0; num_bits < WIDTH; num_bits++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) (~options_row_t[row][num_bits], is_hot);
                assign new_options_row_t[row][num_bits] = is_hot ? ~options_row_t[row][num_bits] : 0;
            end
        end 
        for(col = 0; col < WIDTH; col++) begin: col_calc
            for(sub_row = 0; sub_row < WIDTH; sub_row++) begin: sub_row_calc
                for(sub_col = 0; sub_col < WIDTH; sub_col++) begin: sub_col_calc
                    assign options_col_t[col][sub_row][sub_col] = options[sub_col][col][sub_row];
                    assign new_options_col[sub_col][col][sub_row] = new_options_col_t[col][sub_row][sub_col];
                end 
            end 
            for(num_bits = 0; num_bits < WIDTH; num_bits++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) (~options_col_t[col][num_bits], is_hot);
               assign new_options_col_t[col][num_bits] = is_hot ? ~options_col_t[col][num_bits] : 'hF;
            end
        end 
        for(sector = 0; sector < WIDTH; sector++) begin: sector_calc
            for(row = 0; row < N; row++) begin: row_calc
                for(col = 0; col < N; col++) begin: col_calc
                    for(sub_col = 0; sub_col < WIDTH; sub_col++) begin: sub_col_calc
                        assign options_sector_t[sector][row*N+col][sub_col] = options[sub_col][col][row]; //DOESN'T WORK
                    end 
                end 
            end
            for(num_bits = 0; num_bits < WIDTH; num_bits++) begin: one_hot
                logic is_hot;
                one_hot_detector #(WIDTH) (~options_sector_t[sector][num_bits], is_hot);
                assign new_options_sector_t[sector][num_bits] = is_hot ? ~options_sector_t[sector][num_bits] : 0;
            end
        end 
    endgenerate

endmodule: solver

/*
module square(
    input logic [8:0] row, col, group,
    output [8:0] options);    

    assign options = row | col | group | tried;
    assign all_ones = &options;
    one_hot_detector(~options, options_one_hot);
    assign value_to_load = ~options;

endmodule: square
*/

module one_hot_detector #(parameter WIDTH = 9) (
    input logic [WIDTH-1:0] in,
    output logic is_one_hot);

    assign is_one_hot = (in && !(in & (in-1)));   
    
endmodule

module solver_TB;

  logic [3:0][3:0][3:0] options, options_col_t;
  logic [3:0][3:0][3:0] new_options_row, new_options_col, new_options_sector;

  solver #(4, 2) DUT(.*);

  initial begin
    $monitor("input:\n%b\n%b\n%b\n%b\n\ntranspose:\n%b\n%b\n%b\n%b\n\nresult:\n%b\n%b\n%b\n%b", options[3],options[2],options[1],options[0], options_col_t[3], options_col_t[2], options_col_t[1], options_col_t[0], new_options_col[3], new_options_col[2], new_options_col[1], new_options_col[0],);
    options = 64'h113F223F002322F3;
    #5 $finish;
  end

endmodule: solver_TB
