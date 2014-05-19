module inifile;

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
