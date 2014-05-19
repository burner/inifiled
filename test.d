import inifile;
import initest;

void main() {
	Person p;

	readINIFile(p, "filename.ini");
	writeINIFile(p, "filename.ini");
}
