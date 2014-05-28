module inifile;

import std.algorithm;
import std.stdio;
import std.conv;
import std.range;
import std.format;
import std.traits;
import std.string;

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

bool isINI(T)() @trusted {
	foreach(it; __traits(getAttributes, T)) {
		if(is(typeof(it) == INI)) {
			return true;
		}
	}
	return false;
}

bool isINI(T, string mem)() @trusted {
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		if(is(typeof(it) == INI)) {
			return true;
		}
	}
	return false;
}

string getINI(T)() @trusted {
	foreach(it; __traits(getAttributes, T)) {
		if(isINI!(T)) {
			return it.msg;
		}
	}
	assert(false);
}

string getINI(T, string mem)() @trusted {
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		if(isINI!(T, mem)) {
			return it.msg;
		}
	}
	assert(false, mem);
}

string getTypeName(T)() @trusted {
	return fullyQualifiedName!T;
}

string buildStructParser(T)() {
	string ret = "switch(it) { \n";
	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T, it) && (
			isBasicType!(typeof(__traits(getMember, T, it))) ||
			isSomeString!(typeof(__traits(getMember, T, it))))
		) {
			ret ~= 
				"case \"%s\": t.%s = to!typeof(t.%s)(it); break; %s"
				.format(it, it, it, "\n");
		}
	}

	return ret;
}

void readINIFile(T)(ref T t, string filename) {
	auto iFile = File(filename, "r");
	auto iRange = iFile.byLine();
	readINIFileImpl(t, iRange);
}

bool isSection(T)(T line) @safe nothrow if(isInputRange!T) {

	bool f;
	bool b;

	foreach(it; line) {
		if(it == ' ' || it == '\t') {
			continue;
		} else if(it == '[') {
			f = true;
			break;
		}
	}

	foreach_reverse(it; line) {
		if(it == ' ' || it == '\t') {
			continue;
		} else if(it == '[') {
			f = true;
			break;
		}
	}

	return f && b;
}

pure string getSection(string line) @safe {
	ptrdiff_t f = line.indexOf('[');
	ptrdiff_t b = line.lastIndexOf(']');

	return line[f+1 .. b].idup;
}

unittest {
	assert(getSection("[initest.Person]") == "initest.Person",
		getSection("[initest.Person]"));
	assert(getSection(" [initest.Person]") == "initest.Person",
		getSection("[initest.Person]"));
	assert(getSection(" [initest.Person] ") == "initest.Person",
		getSection("[initest.Person]"));
	assert(getSection("[initest.Person] ") == "initest.Person",
		getSection("[initest.Person]"));
}

string buildSectionParse(T)() @safe {
	string ret = "switch(line) {\n";

	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T, it) && !isBasicType!(typeof(__traits(getMember, T, it))) 
			&& !isSomeString!(typeof(__traits(getMember, T, it))) 
			&& !isArray!(typeof(__traits(getMember, T, it))))
		{
			ret ~= "case %s: readINIFileImpl(this.%s, input); break;\n".format(
				it, it);
		}
	}

	return ret ~ "}\n";
}

void readINIFileImpl(T,IRange)(ref T t, IRange input) {
	foreach(line; input) {
		if(line.startsWith(";")) {
			continue;
		}

		if(isSection(line)) {
			pragma(msg, buildSectionParse!(T));
		}

	}
}

void writeComment(ORange,IRange)(ORange orange, IRange irange) @trusted 
	if(isOutputRange!(ORange, ElementType!IRange) && isInputRange!IRange)
{
	size_t idx = 0;
	foreach(it; irange) {
		if(idx % 77 == 0) {
			orange.put("; ");
		}
		orange.put(it);

		if((idx+1) % 77 == 0) {
			orange.put('\n');
		}

		++idx;
	}
	orange.put('\n');
}

void writeValue(ORange,T)(ORange orange, string name, T value) @trusted 
	if(isOutputRange!(ORange, string))
{

	orange.formattedWrite("%s=\"%s\"\n", name, value);
}

string removeFromLastPoint(string input) @safe {
	ptrdiff_t lDot = input.lastIndexOf('.');
	if(lDot != -1 && lDot+1 != input.length) {
		return input[lDot+1 .. $];
	} else {
		return input;
	}
}

void writeValues(ORange,T)(ORange oRange, string name, T value) @trusted 
	if(isOutputRange!(ORange, string)) //&& isArray!(T))
{
	static if(isSomeString!(ElementType!T) || isBasicType!(ElementType!T)) {
		oRange.formattedWrite("%s=\"%s\"\n", removeFromLastPoint(name), 
			joiner(value.map!(a => to!string(a)), "\",\"")
		);
	} else {
		for(size_t i = 0; i < value.length; ++i) {
			oRange.formattedWrite("[%s]\n", name);
			writeINIFileImpl(value[i], oRange, false);
		}
	}
}

void writeINIFile(T)(ref T t, string filename) @trusted {
	auto oFile = File(filename, "w");
	auto oRange = oFile.lockingTextWriter();
	writeINIFileImpl(t, oRange, true);
}

void writeINIFileImpl(T,ORange)(ref T t, ORange oRange, bool section) 
		@trusted 
{
	if(isINI!T && section) {
		writeComment(oRange, getINI!T());
	}

	if(section) {
		oRange.formattedWrite("[%s]\n", getTypeName!T);
	}

	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T,it)) {
			static if(isBasicType!(typeof(__traits(getMember, T, it))) ||
				isSomeString!(typeof(__traits(getMember, T, it)))) 
			{
				writeComment(oRange, getINI!(T,it));
				writeValue(oRange, it, __traits(getMember, t, it));
			} else static if(isArray!(typeof(__traits(getMember, T, it)))) {
				writeComment(oRange, getINI!(T,it));
				writeValues(oRange, getTypeName!T ~ "." ~ it, 
					__traits(getMember, t, it));
			} else static if(isINI!(typeof(__traits(getMember, t, it)))) {
				writeINIFileImpl(__traits(getMember, t, it), oRange, true);
			}
		}
	}
}
