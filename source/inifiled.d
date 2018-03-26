module inifiled;

import std.range : isInputRange, isOutputRange, ElementType;

string genINIparser(T)() {
	return "";
}

struct INI {
	string msg;
	string name;

	static INI opCall(string s, string name = null) {
		INI ret;
		ret.msg = s;
		ret.name = name;

		return ret;
	}
}

INI getINI(T)() @trusted {
	import std.traits : hasUDA;
	foreach(it; __traits(getAttributes, T)) {
		static if (is(it == INI))
			return INI(null, null);
		static if (is(typeof(it) == INI))
			return it;
	}
	assert(false);
}

INI getINI(T, string mem)() @trusted {
	import std.traits : hasUDA;
	foreach(it; __traits(getAttributes, __traits(getMember, T, mem))) {
		static if (is(it == INI))
			return INI(null, null);
		static if (is(typeof(it) == INI))
			return it;
	}
	assert(false, mem);
}

string getTypeName(T)() @trusted {
	import std.traits : fullyQualifiedName;
	return fullyQualifiedName!T;
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
	import std.array : join;
	import std.format : format;
	string[] ret;

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI)
			&& !isBasicType!(typeof(__traits(getMember, T, it)))
			&& !isSomeString!(typeof(__traits(getMember, T, it)))
			&& !isArray!(typeof(__traits(getMember, T, it))))
		{
			alias MemberType = typeof(__traits(getMember, T, it));
			static if (__traits(compiles, getINI!(MemberType)))
				const name = getINI!(MemberType).name is null
					? fullyQualifiedName!(typeof(__traits(getMember, T, it)))
					: getINI!(MemberType).name;
			else
				const name = fullyQualifiedName!(typeof(__traits(getMember, T, it)));
			ret ~= ("case \"%s\": { line = readINIFileImpl" ~
					"(t.%s, input, depth+1); } ").
				format(name,it);
		}
	}

	// Avoid DMD switch fallthrough warnings
	if (ret.length) {
		return "switch(getSection(line)) { // " ~ fullyQualifiedName!T ~ "\n" ~
			ret.join("goto case; \n") ~ "goto default;\n default: return line;\n}\n";
	} else {
		return "return line;";
	}
}

string buildValueParse(T)() @safe {
	import std.traits : hasUDA, fullyQualifiedName, isArray, isBasicType, isSomeString;
	import std.format : format;
	string ret = "switch(getKey(line)) { // " ~ fullyQualifiedName!T ~ "\n";

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI) && (isBasicType!(typeof(__traits(getMember, T, it)))
			|| isSomeString!(typeof(__traits(getMember, T, it)))))
		{
			const string name = getINI!(T, it).name is null ? it : getINI!(T, it).name;
			ret ~= ("case \"%s\": { t.%s = to!(typeof(t.%s))("
				~ "getValue(line)); break; }\n").format(name, it, it);
		} else if(hasUDA!(__traits(getMember, T, it), INI)
				&& isArray!(typeof(__traits(getMember, T, it))))
		{
			const string name = getINI!(T, it).name is null ? it : getINI!(T, it).name;
			ret ~= ("case \"%s\": { t.%s = to!(typeof(t.%s))("
				~ "getValueArray(line).split(',')); break; }\n").format(name, it, it);
		}
	}

	return ret ~ "default: break;\n}\n";
}

string readINIFileImpl(T,IRange)(ref T t, ref IRange input, int depth = 0)
		if(isInputRange!IRange)
{
	import std.conv : to;
	import std.string : split;
	import std.algorithm.searching : startsWith;
	import std.traits : hasUDA, fullyQualifiedName;
	debug {
		import std.stdio : writefln;
	}
	debug {
		writefln("%*s%d %s %x", depth, "", __LINE__, fullyQualifiedName!(typeof(t)),
			cast(void*)&input);
	}
	string line;
	bool isMultiLine;
	while(!input.empty()) {
		import std.algorithm : endsWith;
		import std.string : stripRight;
		immutable bool wasMultiLine = isMultiLine;
		auto currentLine = input.front.stripRight;
		isMultiLine = currentLine.endsWith(`\`);
		// remove backslash if existent
		if (isMultiLine) {
			currentLine = currentLine[0 .. $ - 1];
		}

		if (wasMultiLine) {
			line ~= currentLine;
		} else {
			line = currentLine.idup;
		}

		input.popFront();

		if(line.startsWith(";") || isMultiLine) {
			continue;
		}
		debug {
			writefln("%*s%d %s %s %b", depth, "", __LINE__, line, fullyQualifiedName!T,
				isSection(line));
		}

		static if (hasUDA!(T, INI))
			const name = getINI!T().name is null ? fullyQualifiedName!T : getINI!T().name;
		else
			const name = fullyQualifiedName!T;
		if(isSection(line) && getSection(line) != name) {
			debug {
				pragma(msg, buildSectionParse!(T));
				writefln("%*s%d %s", depth, "", __LINE__, getSection(line));
				writefln("%*s%d %x", depth, "", __LINE__,
					cast(void*)&input);
			}

			mixin(buildSectionParse!(T));
		} else if(isKeyValue(line)) {
			debug {
				pragma(msg, buildValueParse!(T));
				writefln("%*s%d %s %s", depth, "", __LINE__, getKey(line),
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
		writeComment(oRange, getINI!T().msg);
	}

	if(section) {
		if (hasUDA!(T, INI))
		{
			auto ini = getINI!(T);
			if (ini.name !is null)
				oRange.formattedWrite("[%s]\n", ini.name);
			else
				oRange.formattedWrite("[%s]\n", getTypeName!T);
		}
		else
			oRange.formattedWrite("[%s]\n", getTypeName!T);
	}

	foreach(it; __traits(allMembers, T)) {
		if(hasUDA!(__traits(getMember, T, it), INI)) {
			static if(isBasicType!(typeof(__traits(getMember, T, it))) ||
				isSomeString!(typeof(__traits(getMember, T, it))))
			{
				const ini = getINI!(T,it);
				const name = ini.name is null ? it : ini.name;
				writeComment(oRange, ini.msg);
				writeValue(oRange, name, __traits(getMember, t, it));
			} else static if(isArray!(typeof(__traits(getMember, T, it)))) {
				const ini = getINI!(T,it);
				const name = getTypeName!T ~ "." ~ (ini.name is null ? it : ini.name);
				writeComment(oRange, ini.msg);
				writeValues(oRange, name, __traits(getMember, t, it));
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

@INI("A Spouse")
struct Spouse {
	@INI("The firstname of the spouse")
	string firstname;

	@INI("The age of the spouse")
	int age;

	@INI("The House of the spouse")
	House house;

	bool opEquals(Spouse other) {
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

	@INI("A Spouse")
	Spouse spouse;

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
			&& this.spouse == other.spouse
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

	p.spouse.firstname = "World";
	p.spouse.age = 72;

	p.spouse.house.rooms = 5;
	p.spouse.house.floors = 2;

	p.dog.name = "Wuff";
	p.dog.kg = 3.14;

	Person p2;
	readINIFile(p2, "test/filename.ini");
	writefln("\n%s\n", p2);
	writeINIFile(p2, "test/filenameTmp.ini");

	Person p3;
	readINIFile(p3, "test/filenameTmp.ini");

	if(p2 != p3) {
		writefln("\n%s\n%s", p2, p3);
		writefln("Spouse equal %b", p2.spouse == p3.spouse);
		writefln("Dog equal %b", p2.dog == p3.dog);
		assert(false);
	}
	if(p != p3) {
		writefln("\n%s\n%s", p, p3);
		writefln("Spouse equal %b", p.spouse == p3.spouse);
		writefln("Dog equal %b", p.dog == p3.dog);
		assert(false);
	}
	if(p != p2) {
		writefln("\n%s\n%s", p, p2);
		writefln("Spouse equal %b", p.spouse == p2.spouse);
		writefln("Dog equal %b", p.dog == p2.dog);
		assert(false);
	}
}

version(unittest) {
	enum Check : string { disabled = "disabled"}

	@INI
	struct StaticAnalysisConfig {
		@INI
		string style_check = Check.disabled;

		@INI
		ModuleFilters filters;

		@INI @ConfuseTheParser
		string multi_line;
	}

	private template ModuleFiltersMixin(A) {
		const string ModuleFiltersMixin = () {
			string s;
			foreach (mem; __traits(allMembers, StaticAnalysisConfig))
				static if (is(typeof(__traits(getMember, StaticAnalysisConfig, mem)) == string))
					s ~= `@INI string[] ` ~ mem ~ ";\n";

			return s;
		}();
	}

	@INI
	struct ModuleFilters { mixin(ModuleFiltersMixin!int); }
}

unittest {
	StaticAnalysisConfig config;
	readINIFile(config, "test/dscanner.ini");
	assert(config.style_check == "disabled");
	assert(config.multi_line == `+std.algorithm -std.foo `);
	assert(config.filters.style_check == ["+std.algorithm"]);
}

version (unittest)
struct ConfuseTheParser;

unittest {
	@INI("Reactor Configuration", "reactorConfig")
	struct NukeConfig
	{
		@INI double a;
		@INI double b;
		@INI double c;
	}

	@INI("General Configuration", "general")
	struct Configuration
	{
		@INI("Color of the bikeshed", "shedColor") string shedC;
		@INI @ConfuseTheParser NukeConfig nConfig;
	}

	Configuration c = Configuration("blue");
	c.nConfig.a = 1;
	c.nConfig.b = 2;
	c.nConfig.c = 3;
	c.writeINIFile("test/bikeShed.ini");
	Configuration c2;
	readINIFile(c2, "test/bikeShed.ini");
	assert(c2.shedC == "blue");
	assert(c2.nConfig.a == 1);
	assert(c2.nConfig.b == 2);
	assert(c2.nConfig.c == 3);
}
