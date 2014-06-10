inifile-D
=========

A compile time ini file parser and writter generator for D.
inifile.d takes annotated structs and create ini file parser and writer.
The ini file format always comments and section and to some degree nesting.

Example
-------

```d
import initest;

import inifile;

@INI("A child must have a parent")
struct Child {
	@INI("The firstname of the child")
	string firstname;

	@INI("The age of the child")
	int age;
}

@INI("A Spose")
struct Spose {
	@INI("The firstname of the spose")
	string firstname;

	@INI("The age of the spose")
	int age;

	@INI("The House of the spose")
	House house;
}

@INI("A Dog")
struct Dog {
	@INI("The name of the Dog")
	string name;

	@INI("The food consumed")
	float kg;
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
	string[] someStrings;

	@INI("Some ints")
	int[] someInts;

	int dontShowThis;

	@INI("A Spose")
	Spose spose;

	@INI("The family dog")
	Dog dog;
}

@INI("A House")
struct House {
	@INI("Number of Rooms")
	uint rooms;

	@INI("Number of Floors")
	uint floors;
}
```

```d
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

	p.spose.firstname = "World";
	p.spose.age = 72;

	p.spose.house.rooms = 5;
	p.spose.house.floors = 2;

	p.dog.name = "Wuff";
	p.dog.kg = 3.14;

	writeINIFile(p, "filename.ini");
	Person p2;
	readINIFile(p2, "filename.ini");

	assert(p == p2, format("%s\n%s", p, p2));
	writeln(p2);
}
```
