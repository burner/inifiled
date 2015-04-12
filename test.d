import inifiled;

import initest;
import std.string;
import std.stdio;

void main() {
	Person p;
	p.firstname = "Foo";
	p.lastname = "Bar";
	p.age = 1337;
	p.height = 7331.0;

	p.someStrings ~= "Hello";
	p.someStrings ~= "World";

	p.someInts ~= [1,2];

	/*
	p.spose.firstname = "World";
	p.spose.age = 72;

	p.spose.house.rooms = 5;
	p.spose.house.floors = 2;

	p.dog.name = "Wuff";
	p.dog.kg = 3.14;
	*/

	writeINIFile(p, "filename.ini");
	Person p2;
	readINIFile(p2, "filename.ini");

	assert(p == p2, format("%s\n%s", p, p2));
	writeln(p2);

	readINIFile(p2, "filenamefoobar.ini");
}
