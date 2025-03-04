module therm;

import therm.os_core;

struct Therm {
    this(OsCore core)
    in (core !is null)
    {
        this.core = core;
    }

    static Therm create() {
        version (Windows) {
            import therm.windows;
            return Therm(new WindowsCore());
        } else version (Posix) {
            static assert(false, "todo: not implemented");
        } else {
            static assert(false, "OS not supported");
        }
    }

    void write(T...)(T args) {
        import std.conv : text;
        core.write(text(args));
    }

    void writeln(T...)(T args) {
        write!(args, '\n');
    }

    void writef(alias fmt, T...)(T args) {
        import std.format : format;
        core.write(format!fmt(args));
    }

    void writefln(alias fmt, T...)(T args) {
        writef!(fmt ~ "\n")(args);
    }

    string readln(in string prompt) {
        assert(false, "todo: not implemented");
    }

    private OsCore core;
}
