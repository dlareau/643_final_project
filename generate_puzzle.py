puzzle  = "080000150"
puzzle += "406509080"
puzzle += "000008000"
puzzle += "000000000"
puzzle += "002040003"
puzzle += "300801000"
puzzle += "900070000"
puzzle += "600000004"
puzzle += "150000090"

output = ""
print puzzle
for i in range(9):
	output += "initial_vals[" + str(i) + "] = " + str(9*9) + "'b"
	for j in range(9):
		temp = ["0","0","0","0","0","0","0","0","0"]
		#print i*9+j
		index = puzzle[i*9+j]
		#print index
		if(index != "0"):
			temp[9-int(index)] = "1"
		output += "".join(temp) + "_"
	output += ";\n"
print output