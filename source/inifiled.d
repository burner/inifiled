module inifiled;

import std.range : isInputRange, isOutputRange, ElementType;

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

string getINI(T)() @trusted {
	import std.traits : hasUDA;
	foreach(it; __traits(getAttributes, T)) {
		if(hasUDA!(T, INI)) {
			return it.msg;
		}
	}
	assert(false);
}

string getINI(T, string mem)() @trusted {
	import std.traits : hasUDA;
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		if(hasUDA!(__traits(getMember, T, mem), INI)) {
			return it.msg;
		}
	}
	assert(false, mem);
}

string getTypeName(T)() @trusted {
	import std.traits : fullyQualifiedName;
	return fullyQualifiedName!T;
}

string buildStructParser(T)() {
	import std.traits : hasUDA;
	string ret = "switch(it) { \n";
	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI) && (
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
	import std.stdio : File;
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
	import std.string : indexOf, strip;
	import std.exception : enforce;

	ptrdiff_t eq = line.indexOf('=');
	enforce(eq != -1, "key value pair needs equal sign");

	return line[0 .. eq].strip();
}

unittest {
	assert(getKey("firstname=\"Foo\"") == "firstname");
	assert(getKey("lastname =\"Foo\",\"Bar\"") == "lastname");
}

pure string getTimpl(char l, char r, T)(T line) @safe if(isInputRange!T) {
	import std.string : indexOf, lastIndexOf;
	import std.format : format;
	ptrdiff_t l = line.indexOf(l);
	ptrdiff_t r = line.lastIndexOf(r);

	assert(l+1 < line.length, format("l+1 %u line %u", l+1, line.length));
	return line[l+1 .. r].idup;
}

pure bool isKeyValue(T)(T line) @safe if(isInputRange!T) {
	import std.string : indexOf;
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
	import std.traits : hasUDA, fullyQualifiedName, isBasicType, isSomeString,
		   isArray;
	import std.format : format;
	string ret = "switch(getSection(line)) { // " ~ fullyQualifiedName!T ~ "\n";

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI) 
			&& !isBasicType!(typeof(__traits(getMember, T, it))) 
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
	import std.traits : hasUDA, fullyQualifiedName, isArray, isBasicType, isSomeString;
	import std.format : format;
	string ret = "switch(getKey(line)) { // " ~ fullyQualifiedName!T ~ "\n";

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI) && (isBasicType!(typeof(__traits(getMember, T, it))) 
			|| isSomeString!(typeof(__traits(getMember, T, it)))))
		{
			ret ~= ("case \"%s\": { t.%s = to!(typeof(t.%s))("
				~ "getValue(line)); break; }\n").format(it, it, it);
		} else if(hasUDA!(__traits(getMember, T, it), INI) 
				&& isArray!(typeof(__traits(getMember, T, it)))) 
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
	import std.conv : to;
	import std.string : split;
	debug {
		import std.stdio : writefln;
		import std.traits : fullyQualifiedName;
		import std.algorithm.searching : startsWith;
	}
	debug {
		writefln("%*s%d %s %x", deaph, "", __LINE__, fullyQualifiedName!(typeof(t)),
			cast(void*)&input);
	}
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
	import std.traits : isArray, isSomeString;
	import std.format : formattedWrite;
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
	import std.string : lastIndexOf;
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
	import std.traits : isBasicType, isSomeString;
	import std.format : formattedWrite;
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
	import std.stdio : File;
	auto oFile = File(filename, "w");
	auto oRange = oFile.lockingTextWriter();
	writeINIFileImpl(t, oRange, true);
}

void writeINIFileImpl(T,ORange)(ref T t, ORange oRange, bool section) 
		@trusted 
{
	import std.traits : getUDAs, hasUDA, Unqual, isArray, isBasicType,
		   isSomeString;
	import std.format : formattedWrite;
	if(hasUDA!(T, INI) && section) {
		writeComment(oRange, getINI!T());
	}

	if(section) {
		oRange.formattedWrite("[%s]\n", getTypeName!T);
	}

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI)) {
			static if(isBasicType!(typeof(__traits(getMember, T, it))) ||
				isSomeString!(typeof(__traits(getMember, T, it)))) 
			{
				writeComment(oRange, getINI!(T,it));
				writeValue(oRange, it, __traits(getMember, t, it));
			} else static if(isArray!(typeof(__traits(getMember, T, it)))) {
				writeComment(oRange, getINI!(T,it));
				writeValues(oRange, getTypeName!T ~ "." ~ it, 
					__traits(getMember, t, it));
			//} else static if(isINI!(typeof(__traits(getMember, t, it)))) {
			} else static if(hasUDA!(__traits(getMember, t, it),INI))
			{
				writeINIFileImpl(__traits(getMember, t, it), oRange, true);
			}
		}
	}
}

version(unittest) {
@INI("A child must have a parent")
struct Child {
	@INI("The firstname of the child")
	string firstname;

	@INI("The age of the child")
	int age;

	bool opEquals(Child other) {
		return this.firstname == other.firstname
			&& this.age == other.age;
	}
}

@INI("A Spose")
struct Spose {
	@INI("The firstname of the spose")
	string firstname;

	@INI("The age of the spose")
	int age;

	@INI("The House of the spose")
	House house;

	bool opEquals(Spose other) {
		return this.firstname == other.firstname
			&& this.age == other.age
			&& this.house == other.house;
	}
}

@INI("A Dog")
struct Dog {
	@INI("The name of the Dog")
	string name;

	@INI("The food consumed")
	float kg;

	bool opEquals(Dog other) {
		import std.math : approxEqual, isNaN;
		return this.name == other.name
			&& (approxEqual(this.kg, other.kg)
					|| (isNaN(this.kg) && isNaN(other.kg))
				);
	}
}

@INI("A Person")
struct Person {
	@INI("The firstname of the Person")
	string firstname;
	
	@INI("The lastname of the Person")
	string lastname;

	@INI("The age of the Person")
	int age;

	@INI("The height of the Person")
	float height;

	@INI("Some strings with a very long long INI description that is longer" ~
		" than eigthy lines hopefully."
	)
	string[] someStrings = [":::60180", "asd"];

	@INI("Some ints")
	int[] someInts;

	int dontShowThis;

	@INI("A Spose")
	Spose spose;

	@INI("The family dog")
	Dog dog;

	bool opEquals(Person other) {
		import std.math : approxEqual, isNaN;
		import std.algorithm.comparison : equal;
		return this.firstname == other.firstname
			&& this.lastname == other.lastname
			&& this.age == other.age
			&& (approxEqual(this.height, other.height)
				|| (isNaN(this.height) && isNaN(other.height)))
			&& equal(this.someStrings, other.someStrings)
			&& equal(this.someInts, other.someInts)
			&& this.spose == other.spose
			&& this.dog == other.dog;
	}
}

@INI("A House")
struct House {
	@INI("Number of Rooms")
	uint rooms;

	@INI("Number of Floors")
	uint floors;

	bool opEquals(House other) {
		return this.rooms == other.rooms
			&& this.floors == other.floors;
	}
}
}

unittest {
	import std.stdio : writefln;
	Person p;
	p.firstname = "Foo";
	p.lastname = "Bar";
	p.age = 1337;
	p.height = 7331.0;

	p.someStrings ~= "Hello";
	p.someStrings ~= "World";

	p.someInts ~= [1,2];

	p.spose.firstname = "World";
	p.spose.age = 72;

	p.spose.house.rooms = 5;
	p.spose.house.floors = 2;

	p.dog.name = "Wuff";
	p.dog.kg = 3.14;

	Person p2;
	readINIFile(p2, "filename.ini");
	writefln("\n%s\n", p2);
	writeINIFile(p2, "filenameTmp.ini");

	Person p3;
	readINIFile(p3, "filenameTmp.ini");

	if(p2 != p3) {
		writefln("\n%s\n%s", p2, p3);
		writefln("Spose equal %b", p2.spose == p3.spose);
		writefln("Dog equal %b", p2.dog == p3.dog);
		assert(false);
	}	
	if(p != p3) {
		writefln("\n%s\n%s", p, p3);
		writefln("Spose equal %b", p.spose == p3.spose);
		writefln("Dog equal %b", p.dog == p3.dog);
		assert(false);
	}	
	if(p != p2) {
		writefln("\n%s\n%s", p, p2);
		writefln("Spose equal %b", p.spose == p2.spose);
		writefln("Dog equal %b", p.dog == p2.dog);
		assert(false);
	}	
}
