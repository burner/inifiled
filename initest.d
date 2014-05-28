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

	int dontShowThis;

	@INI("Some ints")
	int[] someInts;

	@INI("A Spose")
	Spose spose;

	@INI("The childs")
	Child[] childs;
}
