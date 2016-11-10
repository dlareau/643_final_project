#include <stdio.h>
#include <stdbool.h>

// ******** Begin Solution 1

int isAvailable(int puzzle[][9], int row, int col, int num)
{
    int rowStart = (row/3) * 3;
    int colStart = (col/3) * 3;

    for(int i=0; i<9; ++i)
    {
        if (puzzle[row][i] == num) return 0;
        if (puzzle[i][col] == num) return 0;
        if (puzzle[rowStart + (i%3)][colStart + (i/3)] == num) return 0;
    }
    return 1;
}

int fillSudoku(int puzzle[][9], int row, int col)
{
    int i;
    if(row<9 && col<9)
    {
        if(puzzle[row][col] != 0)
        {
            if((col+1)<9) return fillSudoku(puzzle, row, col+1);
            else if((row+1)<9) return fillSudoku(puzzle, row+1, 0);
            else return 1;
        }
        else
        {
            for(i=0; i<9; ++i)
            {
                if(isAvailable(puzzle, row, col, i+1))
                {
                    puzzle[row][col] = i+1;
                    if((col+1)<9)
                    {
                        if(fillSudoku(puzzle, row, col +1)) return 1;
                        else puzzle[row][col] = 0;
                    }
                    else if((row+1)<9)
                    {
                        if(fillSudoku(puzzle, row+1, 0)) return 1;
                        else puzzle[row][col] = 0;
                    }
                    else return 1;
                }
            }
        }
        return 0;
    }
    else return 1;
}

// ******** End Solution 1

// ******** Begin Solution 2

// UNASSIGNED is used for empty cells in sudoku grid
#define UNASSIGNED 0

// N is used for size of Sudoku grid. Size will be NxN
#define N 9

// This function finds an entry in grid that is still unassigned
bool FindUnassignedLocation(int grid[N][N], int &row, int &col);

// Checks whether it will be legal to assign num to the given row,col
bool isSafe(int grid[N][N], int row, int col, int num);

/* Takes a partially filled-in grid and attempts to assign values to
  all unassigned locations in such a way to meet the requirements
  for Sudoku solution (non-duplication across rows, columns, and boxes) */
bool SolveSudoku(int grid[N][N])
{
    int row, col;

    // If there is no unassigned location, we are done
    if (!FindUnassignedLocation(grid, row, col))
       return true; // success!

    // consider digits 1 to 9
    for (int num = 1; num <= 9; num++)
    {
        // if looks promising
        if (isSafe(grid, row, col, num))
        {
            // make tentative assignment
            grid[row][col] = num;

            // return, if success, yay!
            if (SolveSudoku(grid))
                return true;

            // failure, unmake & try again
            grid[row][col] = UNASSIGNED;
        }
    }
    return false; // this triggers backtracking
}

/* Searches the grid to find an entry that is still unassigned. If
   found, the reference parameters row, col will be set the location
   that is unassigned, and true is returned. If no unassigned entries
   remain, false is returned. */
bool FindUnassignedLocation(int grid[N][N], int &row, int &col)
{
    for (row = 0; row < N; row++)
        for (col = 0; col < N; col++)
            if (grid[row][col] == UNASSIGNED)
                return true;
    return false;
}

/* Returns a boolean which indicates whether any assigned entry
   in the specified row matches the given number. */
bool UsedInRow(int grid[N][N], int row, int num)
{
    for (int col = 0; col < N; col++)
        if (grid[row][col] == num)
            return true;
    return false;
}

/* Returns a boolean which indicates whether any assigned entry
   in the specified column matches the given number. */
bool UsedInCol(int grid[N][N], int col, int num)
{
    for (int row = 0; row < N; row++)
        if (grid[row][col] == num)
            return true;
    return false;
}

/* Returns a boolean which indicates whether any assigned entry
   within the specified 3x3 box matches the given number. */
bool UsedInBox(int grid[N][N], int boxStartRow, int boxStartCol, int num)
{
    for (int row = 0; row < 3; row++)
        for (int col = 0; col < 3; col++)
            if (grid[row+boxStartRow][col+boxStartCol] == num)
                return true;
    return false;
}

/* Returns a boolean which indicates whether it will be legal to assign
   num to the given row,col location. */
bool isSafe(int grid[N][N], int row, int col, int num)
{
    /* Check if 'num' is not already placed in current row,
       current column and current 3x3 box */
    return !UsedInRow(grid, row, num) &&
           !UsedInCol(grid, col, num) &&
           !UsedInBox(grid, row - row%3 , col - col%3, num);
}

/* A utility function to print grid  */
void printGrid(int grid[N][N])
{
    for (int row = 0; row < N; row++)
    {
       for (int col = 0; col < N; col++)
             printf("%2d", grid[row][col]);
        printf("\n");
    }
}

// ******* End Solution 2

int main()
{
    int i, j;
    /*
    int puzzle[9][9]={{0, 0, 0, 0, 0, 0, 0, 9, 0},
                      {1, 9, 0, 4, 7, 0, 6, 0, 8},
                      {0, 5, 2, 8, 1, 9, 4, 0, 7},
                      {2, 0, 0, 0, 4, 8, 0, 0, 0},
                      {0, 0, 9, 0, 0, 0, 5, 0, 0},
                      {0, 0, 0, 7, 5, 0, 0, 0, 9},
                      {9, 0, 7, 3, 6, 4, 1, 8, 0},
                      {5, 0, 6, 0, 8, 1, 0, 7, 4},
                      {0, 8, 0, 0, 0, 0, 0, 0, 0}};

    int puzzle[9][9]={{8,0,0,0,0,0,0,0,0},
                      {0,0,3,6,0,0,0,0,0},
                      {0,7,0,0,9,0,2,0,0},
                      {0,5,0,0,0,7,0,0,0},
                      {0,0,0,0,4,5,7,0,0},
                      {0,0,0,1,0,0,0,3,0},
                      {0,0,1,0,0,0,0,6,8},
                      {0,0,8,5,0,0,0,1,0},
                      {0,9,0,0,0,0,4,0,0}};
    */

    int puzzle[9][9]={{0,6,1,0,0,7,0,0,3},
                      {0,9,2,0,0,3,0,0,0},
                      {0,0,0,0,0,0,0,0,0},
                      {0,0,8,5,3,0,0,0,0},
                      {0,0,0,0,0,0,5,0,4},
                      {5,0,0,0,0,8,0,0,0},
                      {0,4,0,0,0,0,0,0,1},
                      {0,0,0,1,6,0,8,0,0},
                      {6,0,0,0,0,0,0,0,0}};


   // int retVal = fillSudoku(puzzle, 0, 0);
    int retVal = SolveSudoku(puzzle);

    //if(SolveSudoku(puzzle)) -- Solution 2
    if(retVal) // Solution 1
    {
        printf("\n+-----+-----+-----+\n");
        for(i=1; i<10; ++i)
        {
            for(j=1; j<10; ++j) printf("|%d", puzzle[i-1][j-1]);
            printf("|\n");
            if (i%3 == 0) printf("+-----+-----+-----+\n");
        }
    }
    else printf("\n\nNO SOLUTION\n\n");

    return 0;
}
