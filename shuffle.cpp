#include <iostream>
#include <vector>
#include <algorithm>
#include <sys/time.h>

using namespace std;

unsigned int get_time() {
	timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec * 1e6 + tv.tv_usec;
}

int main(int argc, char *argv[]) {
	unsigned int seed;
	string *line;
	vector<string*> lines;
	
	if (argc > 1) {
		seed = 0;
		for (char *p = argv[1]; *p != '\0'; ++p) {
			seed = seed * 31 + static_cast<unsigned int>(*p);
		}
	} else {
		seed = get_time();
	}

	srand(seed);

	line = new string;
	while (getline(cin, *line)) {
		lines.push_back(line);
		line = new string;
	}
	delete line;

	for (int i = lines.size() - 1; i >= 1; --i) {
		int j = rand() % (i + 1);
		swap(lines[i], lines[j]);
	}

	for (int i = lines.size() - 1; i >= 0; --i) {
		cout << *lines[i] << endl;
		delete lines[i];
	}
	
	return 0;
}

