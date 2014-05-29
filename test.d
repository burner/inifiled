import inifile;
import initest;
import std.string;

void main() {
	Person p;
	p.firstname = "Foo";
	p.lastname = "Bar";
	p.age = 1337;
	p.height = 7331.0;

	/*
	p.someStrings ~= "Hello";
	p.someStrings ~= "World";

	p.someInts ~= [1,2];
	*/

	p.spose.firstname = "World";
	p.spose.age = 72;

	writeINIFile(p, "filename.ini");
	Person p2;
	readINIFile(p2, "filename.ini");

	assert(p == p2, format("%s\n%s", p, p2));
}
