a2g: a2g.c
	gcc -std=c99 $< -o $@

shuffle: shuffle.cpp
	g++ -O2 $< -o $@

