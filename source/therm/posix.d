module therm.posix;
version (Posix):

import core.sys.posix.termios;
import core.sys.posix.unistd :
    stdin = STDIN_FILENO,
    stdout = STDOUT_FILENO,
    isatty;
import io = std.stdio;
import std.exception : errnoEnforce;
import therm.os_core;

enum IUTF8 = 0x4000; // only useful on linux

class PosixCore : OsCore {
    void write(string s) {
        io.write(s);
    }

    void flush() {
        io.stdout.flush();
    }

    int read(scope int delegate(dchar) f) {
        import core.sys.posix.unistd : read;
        import std.typecons : Yes;
        import std.utf : stride, decodeFront;

        auto prevTios = termios();
        if (isatty(stdin)) {
            errnoEnforce(tcgetattr(stdin, &prevTios) == 0);

            auto newTios = setup(prevTios);

            errnoEnforce(tcsetattr(stdin, TCSAFLUSH, &newTios) == 0);
        }

        scope (exit)
            if (isatty(stdin))
                errnoEnforce(tcsetattr(stdin, TCSAFLUSH, &prevTios) == 0);

        char[4] buf;
        while (true) {
            auto charsRead = read(stdin, &buf[0], 1);
            errnoEnforce(charsRead != -1);
            if (charsRead != 1) break;

            auto len = stride(buf);
            assert(1 <= len && len <= 4);
            if (len > 1) {
                charsRead = read(stdin, &buf[1], len - 1);
                errnoEnforce(charsRead != -1);
                if (charsRead != len - 1) break;
            }

            auto s = buf[0..len];
            auto c = decodeFront!(Yes.useReplacementDchar)(s);
            assert(s.length == 0);

            auto ret = f(c);
            if (ret != 0) return ret;
        }

        return 0;
    }
}

private termios setup(termios prevTios) {
    auto newTios = prevTios;
    // Sets terminal to a quasi-raw mode:
    // For input:
    //   INPCK  - disable parity checking
    //   ICRNL  - don't transform \r to \n
    //   ISTRIP - disable ascii input
    //   IXON   - disable some sort of flow control
    newTios.c_iflag &= ~(INPCK | ICRNL | ISTRIP | IXON);
    //   IUTF8  - (linux only) enable UTF-8 input
    version (Linux) newTios.c_iflag |= IUTF8;

    // For output:
    //   ONLRET - make \n act the same as \r
    newTios.c_oflag |= ONLRET;

    // Control settings:
    //   CS8       - enable 8-bit characters
    newTios.c_cflag |= CS8;
    //   VMIN = 1  - read at least 1 character...
    newTios.c_cc[VMIN] = 1;
    //   VTIME = 0 - and block until you read it
    newTios.c_cc[VTIME] = 0;

    // Various other settings:
    //   ECHO   - disable echo on input
    //   ICANON - disable line-by-line handling
    //   IEXTEN - disable implementation-defined input processing
    newTios.c_lflag &= ~(ECHO | ICANON | IEXTEN);

    return newTios;
}
