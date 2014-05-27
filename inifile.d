module inifile;

import std.stdio;
import std.conv;
import std.range;
import std.format;
import std.traits;

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

void readINIFile(T)(ref T t, string filename) {

}

void writeComment(ORange,IRange)(ORange orange, IRange irange) @trusted 
	if(isOutputRange!(ORange, ElementType!IRange) && isInputRange!IRange)
{
	size_t idx = 0;
	foreach(it; irange) {
		if(idx % 80 == 0) {
			orange.put("; ");
		}
		orange.put(it);

		if(idx+1 % 80 == 0) {
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

void writeValues(ORange,T)(ORange oRange, string name, T value) @trusted 
	if(isOutputRange!(ORange, string)) //&& isArray!(T))
{
	for(size_t i = 0; i < value.length; ++i) {
		oRange.formattedWrite("[%s:%d]\n", name, i);
		writeINIFileImpl(value[i], oRange, false);
	}
}

void writeINIFile(T)(ref T t, string filename) @trusted {
	auto oFile = File(filename, "w");
	auto oRange = oFile.lockingTextWriter();
	writeINIFileImpl(t, oRange, true);
}

void writeINIFileImpl(T,ORange)(ref T t, ORange oRange, bool section) 
		@trusted {
	if(isINI!T && section) {
		writeComment(oRange, getINI!T());
	}

	if(section) {
		oRange.formattedWrite("[%s]\n", getTypeName!T);
	}

	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T,it)) {
			writeComment(oRange, getINI!(T,it));
			static if(isBasicType!(typeof(__traits(getMember, T, it))) ||
				isSomeString!(typeof(__traits(getMember, T, it)))) 
			{
				writeValue(oRange, it, __traits(getMember, t, it));
			} else static if(isArray!(typeof(__traits(getMember, T, it)))) {
				writeValues(oRange, getTypeName!T ~ "." ~ it, 
					__traits(getMember, t, it));
			}
		}
	}
}
