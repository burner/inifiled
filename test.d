import inifiled;

import initest;
import std.format : format;

void main() {
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
	writeINIFile(p2, "filenameTmp.ini");

	Person p3;
	readINIFile(p3, "filenameTmp.ini");

	assert(p2 == p3, format("%s\n%s", p2, p3));
	assert(p == p3, format("%s\n%s", p, p3));
	assert(p == p2, format("%s\n%s", p, p2));
}
