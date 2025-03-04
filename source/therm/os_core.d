module therm.os_core;

interface OsCore {
    void write(string s);
}

class NullCore : OsCore {
    import std.stdio;

    void write(string s) {
        write(s);
    }
}
