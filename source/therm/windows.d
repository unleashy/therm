module therm.windows;
version (Windows):

import core.sys.windows.core;
import std.windows.syserror;
import therm.os_core;

class WindowsCore : OsCore {
    void write(string s) {
        import std.conv : to;

        auto hOut = wenforce(GetStdHandle(STD_OUTPUT_HANDLE));
        uint prevMode;
        if (GetConsoleMode(hOut, &prevMode) == 0) {
            import std.stdio : write;
            return write(s);
        }

        wenforce(
            SetConsoleMode(
                hOut,
                prevMode
                    | ENABLE_PROCESSED_OUTPUT
                    | ENABLE_VIRTUAL_TERMINAL_PROCESSING,
            )
        );
        scope(exit) wenforce(SetConsoleMode(hOut, prevMode));

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

    int read(scope int delegate(dchar) f) {
        auto hIn = wenforce(GetStdHandle(STD_INPUT_HANDLE));
        uint prevMode;
        if (GetConsoleMode(hIn, &prevMode) == 0) {
            return readRedirected(f);
        } else {
            return readNormal(hIn, prevMode, f);
        }
    }

    void flush() {
        import std.stdio : stdout;
        stdout.flush();
    }

    private int readRedirected(scope int delegate(dchar) f) {
        import std.stdio : readln;
        foreach (c; readln()) {
            auto ret = f(c);
            if (ret != 0) return ret;
        }

        return 0;
    }

    private int readNormal(
        HANDLE hIn,
        uint prevMode,
        scope int delegate(dchar) f
    ) {
        import std.typecons : Yes;
        import std.utf : stride, decodeFront;

        wenforce(
            SetConsoleMode(
                hIn,
                prevMode
                    & ~ENABLE_ECHO_INPUT
                    & ~ENABLE_LINE_INPUT
                    | ENABLE_VIRTUAL_TERMINAL_INPUT,
            )
        );
        scope(exit) wenforce(SetConsoleMode(hIn, prevMode));

        wchar[2] buffer;
        while (true) {
            uint charsRead;
            wenforce(ReadConsoleW(hIn, &buffer[0], 1, &charsRead, null));
            if (charsRead != 1) break;

            auto len = stride(buffer);
            assert(1 <= len && len <= 2);
            if (len == 2) {
                charsRead =
                    wenforce(ReadConsoleW(hIn, &buffer[0], 1, &charsRead, null));
                if (charsRead != 1) break;
            }

            auto w = buffer[0 .. len];
            auto c = decodeFront!(Yes.useReplacementDchar)(w);
            assert(w.length == 0);

            auto ret = f(c);
            if (ret != 0) return ret;
        }

        return 0;
    }
}

bool isRedirected(HANDLE handle) {
    uint _;
    return handle !is null && GetConsoleMode(handle, &_) == 0;
}
