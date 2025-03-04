module therm.os_core;

interface OsCore {
    void write(string s);
    int read(scope int delegate(dchar) f);
    void flush();
}

class NullCore : OsCore {
    import std.stdio;

    void write(string s) {
        write(s);
    }

    int read(scope int delegate(dchar) f) {
        foreach (c; readln()) {
            auto ret = f(c);
            if (ret != 0) return ret;
        }

        return 0;
    }

    void flush() {
        stdout.flush();
    }
}
