module inifiled;

import std.algorithm;
import std.exception;
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

template isINI(T) {
	static if (__VERSION__ >= 2068)
		import std.meta : anySatisfy;
	else
		import std.typetuple : anySatisfy;
	enum i(alias U) = is(typeof(U) == INI);
	enum isINI = anySatisfy!(i, __traits(getAttributes, T));
}

template isINI(T, string mem) {
	static if (__VERSION__ >= 2068)
		import std.meta : anySatisfy;
	else
		import std.typetuple : anySatisfy;
	enum i(alias U) = is(typeof(U) == INI);
	enum isINI = anySatisfy!(i, __traits(getAttributes,
		__traits(getMember, T, mem))
	);
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
		} else {
			break;
		}
	}

	foreach_reverse(it; line) {
		if(it == ' ' || it == '\t') {
			continue;
		} else if(it == ']') {
			b = true;
			break;
		} else {
			break;
		}
	}

	return f && b;
}

unittest {
	assert(isSection("[initest.Person]"));
	assert(isSection(" [initest.Person]"));
	assert(isSection(" [initest.Person] "));
	assert(!isSection(";[initest.Person] "));
}

pure string getSection(T)(T line) @safe if(isInputRange!T) {
	return getTimpl!('[',']')(line);
}

pure string getValue(T)(T line) @safe if(isInputRange!T) {
	return getTimpl!('"','"')(line);
}

pure string getValueArray(T)(T line) @safe if(isInputRange!T) {
	return getTimpl!('"','"')(line);
}

unittest {
	assert(getValue("firstname=\"Foo\"") == "Foo");
	assert(getValue("firstname=\"Foo\",\"Bar\"") == "Foo\",\"Bar");
}

pure string getKey(T)(T line) @safe if(isInputRange!T) {
	ptrdiff_t eq = line.indexOf('=');
	enforce(eq != -1, "key value pair needs equal sign");

	return line[0 .. eq].strip();
}

unittest {
	assert(getKey("firstname=\"Foo\"") == "firstname");
	assert(getKey("lastname =\"Foo\",\"Bar\"") == "lastname");
}

pure string getTimpl(char l, char r, T)(T line) @safe if(isInputRange!T) {
	ptrdiff_t l = line.indexOf(l);
	ptrdiff_t r = line.lastIndexOf(r);

	assert(l+1 < line.length, format("l+1 %u line %u", l+1, line.length));
	return line[l+1 .. r].idup;
}

pure bool isKeyValue(T)(T line) @safe if(isInputRange!T) {
	ptrdiff_t idx = line.indexOf('=');
	return idx != -1;
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

	assert(getValue("\"initest.Person\"") == "initest.Person",
		getValue("\"initest.Person\""));
	assert(getValue(" \"initest.Person\"") == "initest.Person",
		getValue("\"initest.Person\""));
	assert(getValue(" \"initest.Person\" ") == "initest.Person",
		getValue("\"initest.Person\""));
	assert(getValue("\"initest.Person\" ") == "initest.Person",
		getValue("\"initest.Person\""));
}

string buildSectionParse(T)() @safe {
	string ret = "switch(getSection(line)) { // " ~ fullyQualifiedName!T ~ "\n";

	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T, it) && !isBasicType!(typeof(__traits(getMember, T, it))) 
			&& !isSomeString!(typeof(__traits(getMember, T, it))) 
			&& !isArray!(typeof(__traits(getMember, T, it))))
		{
			ret ~= ("case \"%s\": { line = readINIFileImpl" ~
					"(t.%s, input, deaph+1); goto repeatL; }\n").
				format(fullyQualifiedName!(typeof(__traits(getMember, T, it))),
					it
				);
		}
	}

	return ret ~ "default: return line;\n}\n";
}

string buildValueParse(T)() @safe {
	string ret = "switch(getKey(line)) { // " ~ fullyQualifiedName!T ~ "\n";

	foreach(it; __traits(allMembers, T)) {
		if(isINI!(T, it) && (isBasicType!(typeof(__traits(getMember, T, it))) 
			|| isSomeString!(typeof(__traits(getMember, T, it)))))
		{
			ret ~= ("case \"%s\": { t.%s = to!(typeof(t.%s))("
				~ "getValue(line)); break; }\n").format(it, it, it);
		} else if(isINI!(T, it) && 
				isArray!(typeof(__traits(getMember, T, it)))) 
		{
			ret ~= ("case \"%s\": { t.%s = to!(typeof(t.%s))("
				~ "getValueArray(line).split(',')); break; }\n").format(it, it, it);
		}
	}

	return ret ~ "default: break;\n}\n";
}

string readINIFileImpl(T,IRange)(ref T t, ref IRange input, int deaph = 0)
		if(isInputRange!IRange) 
{
	debug {
		writefln("%*s%d %s %x", deaph, "", __LINE__, fullyQualifiedName!(typeof(t)),
			cast(void*)&input);
	}
	//foreach(line; input) {
	//ElementType!IRange line;
	string line;
	while(!input.empty()) {
		line = input.front().idup;
		input.popFront();

		repeatL:
		if(line.startsWith(";")) {
			continue;
		}
		debug {
			writefln("%*s%d %s %s %b", deaph, "", __LINE__, line, fullyQualifiedName!T, 
				isSection(line));
		}

		if(isSection(line) && getSection(line) != fullyQualifiedName!T) {
			debug {
				//pragma(msg, buildSectionParse!(T));
				writefln("%*s%d %s", deaph, "", __LINE__, getSection(line));
				writefln("%*s%d %x", deaph, "", __LINE__, 
					cast(void*)&input);
			}
			
			mixin(buildSectionParse!(T));
		} else if(isKeyValue(line)) {
			debug {
				//pragma(msg, buildValueParse!(T));
				writefln("%*s%d %s %s", deaph, "", __LINE__, getKey(line), 
					getValue(line));
			}
			
			mixin(buildValueParse!(T));
		}
	}

	return line;
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
	static if(isArray!T && !isSomeString!T) {
		orange.formattedWrite("%s=\"", name);
		foreach(idx, it; value) {
			if(idx != 0) {
				orange.put(',');
			} 
			orange.formattedWrite("%s", it);
		}
		orange.formattedWrite("\"");
	} else {
		orange.formattedWrite("%s=\"%s\"\n", name, value);
	}
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
	if(isOutputRange!(ORange, string))
{
	static if(isSomeString!(ElementType!T) || isBasicType!(ElementType!T)) {
		oRange.formattedWrite("%s=\"", removeFromLastPoint(name));
		foreach(idx, it; value) {
			if(idx != 0) {
				oRange.put(',');
			} 
			oRange.formattedWrite("%s", it);
		}
		oRange.put('"');
		oRange.put('\n');
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
