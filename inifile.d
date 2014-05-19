module inifile;

import std.stdio;

string genINIparser(T)() {
	return "";
}

struct INI {
	string msg;

	static INI opCall(string s) {
		INI ret;
		ret.msg = s;

		return ret;
	}
}

bool isINI(T, string mem)() @trusted {
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		if(is(typeof(it) == INI)) {
			return true;
		} else {
			//writeln(it);
		}
	}
	return false;
}

string getINI(T, string mem)() @trusted {
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		if(is(it : INI)) {
			return it.msg;
		} else {
			writeln(it);
		}
	}
	assert(false, mem);
}

void readINIFile(T)(ref T t, string filename) {

}

void writeINIFile(T)(ref T t, string filename) @trusted {
	auto oFile = File(filename, "w");
	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T,it)) {
			writeln(getINI!(T,it));
		} else {
			//writeln(it);
		}
	}
}
