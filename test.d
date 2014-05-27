import inifile;
import initest;

void main() {
	Person p;

	p.childs ~= Child("Foo", 1);
	p.childs ~= Child("Bar", 2);

	readINIFile(p, "filename.ini");
	writeINIFile(p, "filename.ini");
}
