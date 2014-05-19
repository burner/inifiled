import initest;

import inifile;

@INI("A child must have a parent")
struct Child {
	@INI("The firstname of the child")
	string firstname;

	@INI("The age of the child")
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

	@INI("The childs")
	Child[] childs;
}
