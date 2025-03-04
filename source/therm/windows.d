module therm.windows;
version (Windows):

import core.sys.windows.core;
import std.windows.syserror;
import therm.os_core;

class WindowsCore : OsCore {
    void write(string s) {
        import std.conv : to;

        auto hOut = wenforce(GetStdHandle(STD_OUTPUT_HANDLE));
        if (isRedirected(hOut)) {
            import std.stdio : write;
            return write(s);
        }

        auto w = to!wstring(s);
        while (w.length > 0) {
            uint written;
            wenforce(
                WriteConsoleW(
                    hOut,
                    w.ptr,
                    cast(uint) w.length,
                    &written,
                    null,
                )
            );

            w = w[written .. $];
        }
    }
}

bool isRedirected(HANDLE handle) {
    uint _;
    return handle !is null && GetConsoleMode(handle, &_) == 0;
}
